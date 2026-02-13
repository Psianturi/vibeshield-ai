// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
  function balanceOf(address) external view returns (uint256);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transfer(address to, uint256 amount) external returns (bool);
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IPancakeRouterV2 {
  function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);

  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external;
}

contract VibeGuardVault {
  address public owner;

  IPancakeRouterV2 public immutable router;
  address public immutable wbnb;

  mapping(address => bool) public guardians;

  struct Config {
    bool enabled;
    address stable;
    uint16 slippageBps;   // 0..10000
    uint256 maxAmountIn;  // cap per execution
    bool useWbnbHop;      // path: token->WBNB->stable (recommended)
  }

  // user => token => config
  mapping(address => mapping(address => Config)) public configs;

  event OwnerChanged(address indexed oldOwner, address indexed newOwner);
  event GuardianSet(address indexed guardian, bool enabled);
  event ConfigSet(
    address indexed user,
    address indexed token,
    address indexed stable,
    bool enabled,
    uint16 slippageBps,
    uint256 maxAmountIn,
    bool useWbnbHop
  );

  event EmergencySwapExecuted(
    address indexed guardian,
    address indexed user,
    address indexed tokenIn,
    address stableOut,
    uint256 amountIn,
    uint256 minOut,
    uint256 expectedOut
  );

  error NotOwner();
  error NotGuardian();
  error Disabled();
  error BadSlippage();
  error AmountTooLarge();
  error BadStable();

  modifier onlyOwner() {
    if (msg.sender != owner) revert NotOwner();
    _;
  }

  modifier onlyGuardian() {
    if (!guardians[msg.sender]) revert NotGuardian();
    _;
  }

  constructor(address _router, address _wbnb) {
    owner = msg.sender;
    router = IPancakeRouterV2(_router);
    wbnb = _wbnb;

    guardians[msg.sender] = true;
    emit GuardianSet(msg.sender, true);
  }

  function setOwner(address newOwner) external onlyOwner {
    emit OwnerChanged(owner, newOwner);
    owner = newOwner;
  }

  function setGuardian(address guardian, bool enabled) external onlyOwner {
    guardians[guardian] = enabled;
    emit GuardianSet(guardian, enabled);
  }

  function setConfig(
    address token,
    address stable,
    bool enabled,
    uint16 slippageBps,
    uint256 maxAmountIn,
    bool useWbnbHop
  ) external {
    if (slippageBps > 10_000) revert BadSlippage();
    if (stable == address(0)) revert BadStable();

    configs[msg.sender][token] = Config({
      enabled: enabled,
      stable: stable,
      slippageBps: slippageBps,
      maxAmountIn: maxAmountIn,
      useWbnbHop: useWbnbHop
    });

    emit ConfigSet(msg.sender, token, stable, enabled, slippageBps, maxAmountIn, useWbnbHop);
  }

  /// @notice Guardian-triggered swap pulling user tokens via allowance.
  /// @dev User must have approved this vault to spend `token`.
  function executeEmergencySwap(address user, address token, uint256 amountIn) external onlyGuardian {
    Config memory cfg = configs[user][token];
    if (!cfg.enabled) revert Disabled();
    if (cfg.maxAmountIn > 0 && amountIn > cfg.maxAmountIn) revert AmountTooLarge();

    address[] memory path = _buildPath(token, cfg.stable, cfg.useWbnbHop);

    uint256 expectedOut = _expectedOut(amountIn, path);
    uint256 minOut = (expectedOut * (10_000 - cfg.slippageBps)) / 10_000;

    // pull tokens from user
    require(IERC20(token).transferFrom(user, address(this), amountIn), 'TRANSFER_FROM_FAILED');

    // approve router exact amount
    _forceApprove(token, address(router), 0);
    _forceApprove(token, address(router), amountIn);

    uint256 deadline = block.timestamp + 20 minutes;

    router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
      amountIn,
      minOut,
      path,
      user,
      deadline
    );

    emit EmergencySwapExecuted(msg.sender, user, token, cfg.stable, amountIn, minOut, expectedOut);
  }

  function _buildPath(address token, address stable, bool useWbnbHop) internal view returns (address[] memory) {
    if (useWbnbHop && token != wbnb && stable != wbnb) {
      address[] memory path = new address[](3);
      path[0] = token;
      path[1] = wbnb;
      path[2] = stable;
      return path;
    }

    address[] memory direct = new address[](2);
    direct[0] = token;
    direct[1] = stable;
    return direct;
  }

  function _expectedOut(uint256 amountIn, address[] memory path) internal view returns (uint256) {
    uint256[] memory amounts = router.getAmountsOut(amountIn, path);
    return amounts[amounts.length - 1];
  }

  function _forceApprove(address token, address spender, uint256 amount) internal {
    // Some tokens (e.g., USDT) require allowance to be set to 0 first.
    require(IERC20(token).approve(spender, amount), 'APPROVE_FAILED');
  }

  function rescueToken(address token, address to, uint256 amount) external onlyOwner {
    require(IERC20(token).transfer(to, amount), 'RESCUE_TRANSFER_FAILED');
  }
}
