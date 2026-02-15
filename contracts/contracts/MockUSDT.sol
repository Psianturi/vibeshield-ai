// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Simple 18-decimal mock USDT for stable demos.
/// @dev Not intended for production use.
contract MockUSDT {
  string public constant name = 'Mock USDT';
  string public constant symbol = 'mUSDT';
  uint8 public constant decimals = 18;

  uint256 public totalSupply;
  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  event Transfer(address indexed from, address indexed to, uint256 amount);
  event Approval(address indexed owner, address indexed spender, uint256 amount);

  constructor() {
    _mint(msg.sender, 1_000_000 * 10 ** uint256(decimals));
  }

  /// @notice Faucet: mint 1,000 mUSDT to caller.
  function faucet() external {
    _mint(msg.sender, 1_000 * 10 ** uint256(decimals));
  }

  function approve(address spender, uint256 amount) external returns (bool) {
    allowance[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
  }

  function transfer(address to, uint256 amount) external returns (bool) {
    _transfer(msg.sender, to, amount);
    return true;
  }

  function transferFrom(address from, address to, uint256 amount) external returns (bool) {
    uint256 allowed = allowance[from][msg.sender];
    require(allowed >= amount, 'ALLOWANCE');
    allowance[from][msg.sender] = allowed - amount;
    _transfer(from, to, amount);
    return true;
  }

  function _transfer(address from, address to, uint256 amount) internal {
    require(balanceOf[from] >= amount, 'BALANCE');
    balanceOf[from] -= amount;
    balanceOf[to] += amount;
    emit Transfer(from, to, amount);
  }

  function _mint(address to, uint256 amount) internal {
    totalSupply += amount;
    balanceOf[to] += amount;
    emit Transfer(address(0), to, amount);
  }
}
