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
    "aiModel": "gpt-4o-mini"
  }
}
```

### POST /api/vibe/execute-swap
Execute emergency swap to stablecoin.

**Request:**
```json
{
  "tokenAddress": "0x...",
  "amount": "100"
}
```

## Deployment (Railway)

1. Connect GitHub repo to Railway
2. Add environment variables in Railway dashboard
3. Deploy automatically on push

## Tech Stack
- Node.js + TypeScript
- Express.js
- ethers.js (BSC interaction)
- Kalibr AI (Model routing)
- Cryptoracle (Sentiment data)
- CoinGecko (Price data)
