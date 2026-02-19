# VibeShield AI 🛡️

"Sell the Rumor, Protect the Vibe." — An AI Agent that listens to market whispers before the charts do.

**Tagline:** *"Sell the Rumor, Protect the Vibe."*

AI-powered crypto portfolio guardian that monitors social sentiment and triggers on-chain protection workflows when market risk spikes. Non-custodial, strategy-based agent system on BSC Testnet.

## Good Vibes Only (BNB Chain)

### Tech Stack
- **Backend:** Node.js + TypeScript + Express.js (Railway)
- **Frontend:** Flutter 3.x (Web + Mobile) — deployed to Vercel via GitHub Actions
- **State Management:** Riverpod 2.x
- **Blockchain:** BNB Chain BSC Testnet (chain 97)
- **Smart Contracts:** Solidity + Hardhat (VibeGuardVault, VibeShieldRegistry, VibeShieldRouter)
- **AI:** Kalibr Systems (model routing; configured via env)
- **Data:** Cryptoracle + CoinGecko (realtime market prices)

### Live Deployments
- **Backend:** https://vibeguard-ai-production.up.railway.app
- **Frontend:** Deployed to Vercel (auto-deploy on push to `main`)


## Frontend (Flutter Web) → Vercel (GitHub Actions)

This repo deploys Flutter Web via GitHub Actions (Vercel CLI). Vercel does **not** need Flutter installed.

### 1) Create a Vercel project (one-time)
- Create a new project in Vercel Dashboard.
- Keep **Root Directory** empty (we deploy prebuilt static files).

### 2) Add GitHub Actions secrets (one-time)
In GitHub → **Settings → Secrets and variables → Actions → Secrets**:
- `VERCEL_TOKEN` (Vercel access token)
- `VERCEL_PROJECT_NAME` (your Vercel project name/slug)
- `VERCEL_SCOPE` (optional: team slug/username)

### 3) Set build-time config (recommended)
In GitHub → **Settings → Secrets and variables → Actions → Variables**:
- `API_BASE_URL` (example: `https://<your-railway-domain>.up.railway.app`)

Note: `--dart-define` is **build-time** for Flutter Web.

### 4) Deploy
- Push to `main`.
- Workflow: `.github/workflows/deploy_flutter_web_vercel.yml`

### CORS note (backend)
If you lock down CORS, set Railway `CORS_ORIGIN` to include your Vercel domain, e.g.:
- `CORS_ORIGIN=https://<project>.vercel.app,https://<your-custom-domain>`

## Quick Start

### Backend
```bash
cd backend
npm install
cp .env.example .env
# Edit .env with your API keys
npm run dev
```

### Frontend
```bash
cd frontend/vibeshield_app
flutter pub get
flutter run -d chrome  # Web
flutter run            # Mobile
```

## Project Structure

```
vibeshield-ai/
├── backend/              # Node.js API (Express + TS) + monitor loop
├── contracts/            # VibeShieldVault, Registry, Router (Hardhat)
├── frontend/
│   └── vibeshield_app/
│       └── lib/
│           ├── core/           # Config, agent demo models
│           ├── features/
│           │   ├── home/       # HomeScreen (desktop/mobile layouts), AgentProfileDialog
│           │   ├── dashboard/  # VibeMeter, Sentiment, MultiToken widgets
│           │   ├── insights/   # Token insight cards, InsightsScreen
│           │   └── wallet/     # Wallet connect button
│           ├── models/         # Vibe data models
│           ├── providers/      # Riverpod state providers
│           ├── services/       # API service, Web3 integration
│           └── widgets/        # Reusable widgets (shimmer, multi-token grid, market pulse)
├── .github/workflows/    # CI/CD (Flutter → Vercel)
├── vercel.json           # SPA routing config
└── README.md
```

## Core Features

1. **Market Pulse** — Realtime BTC/BNB/ETH/USDT prices from CoinGecko
2. **AI Sentiment Analysis** — Social signal monitoring via Cryptoracle + Kalibr AI risk scoring
3. **Agent Demo (BSC Testnet)** — Spawn agent → Approve WBNB → Auto-protection flow
4. **Strategy System** — Tight (🛡️ Iron Guardian) or Loose (💎 Ranger) protection strategies
5. **RPG-style Agent Profile** — Clickable agent card with animated glow, strategy-based avatars, live stats
6. **Emergency Swap** — Manual guardian swap execution (collapsible UI, fully on-chain)
7. **Monitor Loop** — Subscription-based auto-execution with cooldown guards
8. **Non-custodial** — All protection via on-chain vault contracts, user retains full custody
9. **Pre-connect Landing** — Hero section explaining value before wallet connect
10. **Pro Trader Desktop Layout** — Split-view 2-column dashboard for desktop/web (>900px)
11. **Market Insights Panel** — Detailed sentiment analysis with TokenInsightCards + detail dialogs
12. **Shimmer Loading** — Skeleton loading states for better UX during data fetches

## What's Implemented

- **Backend API** on Railway with `/health` and `/api/vibe/*` routes
- **Risk pipeline:** `/api/vibe/check` → Cryptoracle + CoinGecko → Kalibr AI → `{ sentiment, price, analysis }`
- **Agent execution:** Router-based protection on BSC Testnet with on-chain `txHash` proofs
- **Multi-user subscriptions:** `/api/vibe/subscribe`, `/api/vibe/subscriptions`, `/api/vibe/run-once`
- **Monitor safety:** Per-subscription cooldown and overlap prevention
- **Agent Demo flow (BSC Testnet):**
  - Step 1: Activate agent (spawn) with strategy selection (Tight/Loose)
  - Step 2: Approve WBNB to router contract
  - Step 3: Agent active — inject black swan event or manual override
  - On-chain status sync (`isAgentActive`, `hasApproval`, balances) — 100% on-chain reads
  - Built-in demo helper: `Get demo WBNB` (backend wraps/transfers for demo readiness)
- **Emergency Swap:** `POST /api/vibe/execute-swap` → guardian calls `vault.executeEmergencySwap()` on-chain
- **Animated Agent Dialog:** Pulsing glow effect on avatar, responsive layout, RPG-style stats
- **Responsive UI:** Mobile-optimized with `ConstrainedBox(maxWidth: 800)`, scrollable dialogs
- **Modular codebase:** `AgentProfileDialog`, `MarketPulseCard` extracted as standalone widgets
- **Desktop Split View (>900px):**
  - Left Column (40%): Wallet connect, token selector, Vibe Meter, Agent Card
  - Right Column (60%): Multi-Token Sentiment Grid (3-col), Market Insights Panel, Market Pulse
- **Multi-Token Dashboard:** 6 tokens (BTC, BNB, ETH, SOL, XRP, SUI) with shimmer skeleton loading
- **Market Insights Panel:** TokenInsightCards with detail dialog (Vibe Score, community stats, signals)


---
