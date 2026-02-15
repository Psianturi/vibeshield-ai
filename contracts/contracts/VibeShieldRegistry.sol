// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice On-chain registry for agent ownership + strategy selection.
/// @dev Not intended for production use.
contract VibeShieldRegistry {
  enum Strategy {
    NONE,
    TIGHT,
    LOOSE
  }

  struct Agent {
    bool isActive;
    Strategy strategy;
    uint256 createdAt;
  }

  address public owner;
  uint256 public creationFee = 0.005 ether; // 0.005 BNB

  mapping(address => Agent) public userAgents;

  event OwnerChanged(address indexed oldOwner, address indexed newOwner);
  event AgentSpawned(address indexed user, Strategy strategy, uint256 feePaid);
  event AgentUpdated(address indexed user, Strategy strategy);
  event FeeChanged(uint256 newFee);
  event FeesWithdrawn(address indexed to, uint256 amount);

  error NotOwner();
  error InvalidStrategy();
  error FeeTooLow();

  modifier onlyOwner() {
    if (msg.sender != owner) revert NotOwner();
    _;
  }

  constructor() {
    owner = msg.sender;
  }

  function setOwner(address newOwner) external onlyOwner {
    emit OwnerChanged(owner, newOwner);
    owner = newOwner;
  }

  function setFee(uint256 newFee) external onlyOwner {
    creationFee = newFee;
    emit FeeChanged(newFee);
  }

  /// @notice Spawn an agent (first time) with fee; subsequent calls update strategy.
  /// @dev Strategy updates are free after first spawn.
  function spawnAgent(Strategy strategy) external payable {
    if (strategy == Strategy.NONE) revert InvalidStrategy();

    Agent storage a = userAgents[msg.sender];
    if (!a.isActive) {
      if (msg.value < creationFee) revert FeeTooLow();
      userAgents[msg.sender] = Agent({ isActive: true, strategy: strategy, createdAt: block.timestamp });
      emit AgentSpawned(msg.sender, strategy, msg.value);
      return;
    }

    a.strategy = strategy;
    emit AgentUpdated(msg.sender, strategy);
  }

  function getAgent(address user) external view returns (bool isActive, Strategy strategy) {
    Agent memory a = userAgents[user];
    return (a.isActive, a.strategy);
  }

  function withdrawFees(address payable to) external onlyOwner {
    uint256 bal = address(this).balance;
    (bool sent, ) = to.call{ value: bal }('');
    require(sent, 'WITHDRAW_FAILED');
    emit FeesWithdrawn(to, bal);
  }
}
