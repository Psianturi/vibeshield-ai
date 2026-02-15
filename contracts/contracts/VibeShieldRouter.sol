// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
  function balanceOf(address) external view returns (uint256);
  function transfer(address to, uint256 amount) external returns (bool);
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IVibeShieldRegistry {
  enum Strategy {
    NONE,
    TIGHT,
    LOOSE
  }

  function getAgent(address user) external view returns (bool isActive, Strategy strategy);
}

/// @notice Safety-oriented demo router: performs a deterministic "mock swap" WBNB -> mUSDT.
/// @dev Not intended for production use.
contract VibeShieldRouter {
  IVibeShieldRegistry public immutable registry;
  IERC20 public immutable wbnb;
  IERC20 public immutable mockUSDT;

  address public owner;
  address public executor;

  // 1 WBNB (1e18) => 600 mUSDT (600e18)
  uint256 public constant RATE_E18 = 600e18;

  event OwnerChanged(address indexed oldOwner, address indexed newOwner);
  event ExecutorChanged(address indexed oldExecutor, address indexed newExecutor);
  event ProtectionExecuted(address indexed user, uint256 amountIn, uint256 amountOut);
  event LiquidityWithdrawn(address indexed token, address indexed to, uint256 amount);

  error NotOwner();
  error NotExecutor();
  error AgentNotActive();
  error NothingToSell();
  error TransferFailed();
  error InsufficientLiquidity();

  modifier onlyOwner() {
    if (msg.sender != owner) revert NotOwner();
    _;
  }

  modifier onlyExecutor() {
    if (msg.sender != executor) revert NotExecutor();
    _;
  }

  constructor(address registry_, address wbnb_, address mockUSDT_, address executor_) {
    owner = msg.sender;
    registry = IVibeShieldRegistry(registry_);
    wbnb = IERC20(wbnb_);
    mockUSDT = IERC20(mockUSDT_);
    executor = executor_;
  }

  function setOwner(address newOwner) external onlyOwner {
    emit OwnerChanged(owner, newOwner);
    owner = newOwner;
  }

  function setExecutor(address newExecutor) external onlyOwner {
    emit ExecutorChanged(executor, newExecutor);
    executor = newExecutor;
  }

  /// @notice Pulls WBNB from user and pays mUSDT back to user.
  /// @dev Requires user allowance to this router.
  function executeProtection(address user, uint256 amountIn) external onlyExecutor {
    (bool isActive, IVibeShieldRegistry.Strategy strat) = registry.getAgent(user);
    if (!isActive) revert AgentNotActive();

    uint256 userBalance = wbnb.balanceOf(user);
    uint256 maxSell;
    if (strat == IVibeShieldRegistry.Strategy.TIGHT) {
      maxSell = userBalance;
    } else if (strat == IVibeShieldRegistry.Strategy.LOOSE) {
      maxSell = userBalance / 2;
    } else {
      revert AgentNotActive();
    }

    uint256 finalSellAmount = amountIn > maxSell ? maxSell : amountIn;
    if (finalSellAmount == 0) revert NothingToSell();

    // Pull WBNB from user.
    if (!wbnb.transferFrom(user, address(this), finalSellAmount)) revert TransferFailed();

    // Mock conversion.
    uint256 amountOut = (finalSellAmount * RATE_E18) / 1e18;
    if (mockUSDT.balanceOf(address(this)) < amountOut) revert InsufficientLiquidity();

    if (!mockUSDT.transfer(user, amountOut)) revert TransferFailed();

    emit ProtectionExecuted(user, finalSellAmount, amountOut);
  }

  function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
    if (!IERC20(token).transfer(to, amount)) revert TransferFailed();
    emit LiquidityWithdrawn(token, to, amount);
  }
}
