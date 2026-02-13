# VibeGuard AI - Backend

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

## Deployment (Railway)

1. Connect GitHub repo to Railway
2. Add environment variables in Railway dashboard
3. Deploy automatically on push

Minimum variables for on-chain execution:
- `BSC_RPC_URL`
- `PRIVATE_KEY` (guardian key)
- `VIBEGUARD_VAULT_ADDRESS`

If you only want the API/healthcheck up, you can leave swap vars unset; `/health` will still work.

## Tech Stack
- Node.js + TypeScript
- Express.js
- ethers.js (BSC interaction)
- Kalibr AI (Model routing)
- Cryptoracle (Sentiment data)
- CoinGecko (Price data)
