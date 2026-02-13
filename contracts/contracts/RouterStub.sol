// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal stub of a V2-like router for testnet deployments.
/// @dev Not intended for production use.
interface IERC20 {
  function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract RouterStub {
  function getAmountsOut(uint256 amountIn, address[] calldata path) external pure returns (uint256[] memory amounts) {
    amounts = new uint256[](path.length);
    for (uint256 i = 0; i < path.length; i++) {
      amounts[i] = amountIn;
    }
  }

  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256,
    address[] calldata path,
    address to,
    uint256
  ) external {
    // Safety behavior for testnets: return tokenIn to the user.
    // Vault approves this router; we just pull tokenIn from the vault and send it back.
    IERC20(path[0]).transferFrom(msg.sender, to, amountIn);
  }
}
