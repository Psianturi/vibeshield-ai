# VibeShield Contracts (BSC Testnet)

This folder contains the Solidity contracts and Hardhat scripts for the **Agent Demo** deployed to **BSC Testnet (chainId 97)**.

## What’s deployed

- `MockUSDT` (mUSDT): mock stablecoin used for deterministic demo flows.
- `VibeShieldRegistry`: paid agent spawn/registry + strategy selection.
- `VibeShieldRouter`: executor-only protection execution; mock WBNB→mUSDT swap with strategy caps.

## Setup

1) Install deps

```bash
npm install
```

2) Create `.env`

Copy from `.env.example` and fill:

- `BSC_TESTNET_RPC_URL`
- `DEPLOYER_PRIVATE_KEY`
- `EXECUTOR_ADDRESS` (backend executor EOA)

## Deploy (BSC Testnet)

This deploys `MockUSDT`, `VibeShieldRegistry`, `VibeShieldRouter`, seeds the router with mUSDT liquidity, and writes a deployment json file.

```bash
npm run deploy:agent-demo:testnet
```

Output is written to:

- `deployments/agent-demo-97.json`

## Verify / Explore

Use BscScan testnet to view contracts/txs:

- https://testnet.bscscan.com/

## Notes

- The router uses a **mock swap** for stability; it does not depend on testnet DEX liquidity.
- Do not commit `.env` (it contains private keys).
