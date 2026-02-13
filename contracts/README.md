# VibeGuard Contracts

This folder contains the non-custodial **VibeGuardVault** contract used for "Option B" autopilot execution.

## What it does
- Users keep funds in their own wallet.
- Users **approve** the vault to spend a specific token.
- Users set their own config (stablecoin, slippage, max amount).
- A backend "guardian" address can trigger `executeEmergencySwap(user, token, amountIn)`.
- The contract pulls tokens via `transferFrom` and swaps via PancakeSwap router **to the user**.

## Install
```bash
cd contracts
npm install
cp .env.example .env
```

## Deploy
```bash
npm run build
npm run deploy:bsc
```

## User onboarding (high level)
1. User calls `setConfig(token, stable, enabled, slippageBps, maxAmountIn, useWbnbHop)`
2. User approves the vault: `approve(vault, amount)` for the `token`
3. Backend stores the user subscription off-chain and triggers swaps when risk is high.

## Notes
- This is hackathon-grade code. For production: add permit support, path config, better access control, audits.
