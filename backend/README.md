# VibeShield AI - Backend

AI-powered sentiment monitoring and risk analysis engine.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your API keys
```

3. Run development server:
```bash
npm run dev
```

## API Endpoints

### POST /api/vibe/check
Check sentiment and risk analysis for a token.

**Request:**
```json
{
  "token": "BTC",
  "tokenId": "bitcoin"
}
```

**Response:**
```json
{
  "sentiment": {
    "token": "BTC",
    "score": 75,
    "timestamp": 1234567890,
    "sources": ["twitter", "telegram"]
  },
  "price": {
    "token": "bitcoin",
    "price": 45000,
    "volume24h": 1000000000,
    "priceChange24h": 2.5
  },
  "analysis": {
    "riskScore": 25,
    "shouldExit": false,
    "reason": "Sentiment is positive, no immediate risk",
    "aiModel": "<kalibr-model-id>"
  }
}
```

### POST /api/vibe/execute-swap
Execute a non-custodial emergency swap via the on-chain vault.

This endpoint returns a **transaction hash** (`txHash`) when the on-chain call succeeds.

**Request:**
```json
{
  "userAddress": "0xYourUserWallet",
  "tokenAddress": "0x...",
  "amount": "100"
}
```

**Response (success):**
```json
{
  "success": true,
  "txHash": "0x..."
}
```

**Response (error):**
```json
{
  "success": false,
  "error": "Missing PRIVATE_KEY"
}
```

## Subscriptions / Monitor
- `GET /api/vibe/subscriptions`
- `POST /api/vibe/subscribe`
- `POST /api/vibe/run-once`
- Monitor behavior:
  - `MONITOR_EXECUTION_COOLDOWN_MS=300000` (default 5 minutes): after a successful on-chain execution, monitor will skip executing again for the same subscription until the cooldown window passes.
  - `MONITOR_AUTO_DISABLE_ON_EXECUTE=false` (default): keep subscription enabled after successful execution.
  - `MONITOR_AUTO_DISABLE_ON_EXECUTE=true`: auto-disable subscription after successful execution.
  - `MONITOR_AUTO_SUBSCRIBE_FROM_AGENT_STATUS=true` (default): auto-upsert `WBNB` subscription when `/agent-demo/status` sees agent active + allowance > 0.
  - `MONITOR_DEFAULT_AMOUNT_WBNB=0.01`: default execution amount for auto-created subscription.
  - `MONITOR_DEFAULT_RISK_THRESHOLD=80`: default monitor threshold for auto-created subscription.

## Demo Hybrid Trigger

- `POST /api/vibe/demo/inject`
  - Injects temporary emergency context (TTL, one-shot) for monitor loop reasoning.
  - Requires:
    - `ENABLE_DEMO_INJECTION=true`
    - Optional secret mode: set `DEMO_INJECTION_REQUIRE_SECRET=true` and provide `DEMO_INJECTION_SECRET` in body (`{ secret, token, type? | headline?, severity?, ttlMs? }`)
  - Does **not** execute swap directly. Monitor loop remains the executor.
- `GET /api/vibe/demo/context`
  - Returns active injected context snapshot (if any).

## On-chain History

- `GET /api/vibe/tx-history?userAddress=0x...&limit=50`
  - Returns a simple file-backed list of recent `txHash` items recorded by either manual swaps or monitor-triggered swaps.

## Debug (disabled by default)

- `GET /api/vibe/debug/models` (only when `DEBUG=true`)
  - Lists Gemini models available to the current `GOOGLE_API_KEY`/`GEMINI_API_KEY` that support `generateContent`.
  - Useful for setting `KALIBR_MODEL_HIGH` / `KALIBR_MODEL_LOW` without guessing model IDs.

## Deployment (Railway)

1. Connect GitHub repo to Railway
2. Add environment variables in Railway dashboard
3. Deploy automatically on push

Minimum variables for Agent Demo on-chain execution:
- `PRIVATE_KEY` (or `AGENT_DEMO_PRIVATE_KEY`) for guardian/executor wallet
- `AGENT_DEMO_RPC_URL` (recommended) or `BSC_TESTNET_RPC_URL`

Deployment address source:
- Keep `backend/deployments/agent-demo-97.json` available in runtime, **or**
- Set `AGENT_DEMO_DEPLOYMENT_PATH` to the absolute path of that deployment file.

For Agent Demo on BSC Testnet (chain 97), set one of:
- `AGENT_DEMO_RPC_URL=https://bsc-testnet-dataseed.bnbchain.org`
- or `BSC_TESTNET_RPC_URL=https://bsc-testnet-dataseed.bnbchain.org`

Legacy/manual vault endpoint notes (`POST /api/vibe/execute-swap`):
- Requires `VIBESHIELD_VAULT_ADDRESS` (alias `VIBEGUARD_VAULT_ADDRESS` is also accepted in code).

If you only want the API/healthcheck up, you can leave swap vars unset; `/health` will still work.

## Tech Stack
- Node.js + TypeScript
- Express.js
- ethers.js (BSC interaction)
- Kalibr AI (Model routing)
- Cryptoracle (Sentiment data)
- CoinGecko (Price data)
