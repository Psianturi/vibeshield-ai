# VibeShield AI - Frontend

Flutter hybrid app (Web + Mobile) for crypto portfolio monitoring.

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Run on web:
```bash
flutter run -d chrome
```

### Production config (no localhost)

By default, **debug** runs use `http://localhost:3000`.

For production run with `--dart-define`:

```bash
flutter run -d chrome \
    --dart-define=API_BASE_URL=https://vibeguard-ai-production.up.railway.app \
    --dart-define=CHAIN_ID=97 \
    --dart-define=RPC_URL=https://bsc-testnet-rpc.publicnode.com \
    --dart-define=EXPLORER_TX_BASE_URL=https://testnet.bscscan.com/tx/
```

### Environment / Build Defines

This app uses `--dart-define` for environment configuration:

- `API_BASE_URL` (optional): backend origin (no `/api`), e.g. `https://...railway.app`
- `WALLETCONNECT_PROJECT_ID` (required for mobile wallet connect): your WalletConnect Project ID

Example:

```bash
flutter run \
    --dart-define=API_BASE_URL=https://vibeguard-ai-production.up.railway.app \
    --dart-define=WALLETCONNECT_PROJECT_ID=YOUR_ID
```

3. Run on mobile:
```bash
flutter run
```

4. Build for production:
```bash
# Web
flutter build web

# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

## Features

- 🎯 Real-time Vibe Meter (Sentiment visualization)
- 📊 Price & Volume tracking
- 🤖 AI-powered risk analysis
- 🔄 Emergency swap execution
- 📱 Responsive design (Web + Mobile)
- 🛡️ Agent setup flow with on-chain status (Activate → Approve → Manual Override)
- 💧 Demo WBNB helper (`Get demo WBNB`) to reduce setup friction during demos

## API used by the app

- `POST /api/vibe/check`
- `POST /api/vibe/execute-swap` (requires `userAddress`)
- `GET /api/vibe/tx-history?userAddress=0x...&limit=50`
- `GET /api/vibe/agent-demo/config`
- `GET /api/vibe/agent-demo/status?userAddress=0x...`
- `POST /api/vibe/agent-demo/topup-wbnb`
- `POST /api/vibe/agent-demo/execute-protection`

## Agent Demo UX (current)

- **Step 1 — Activate agent:** spawn the agent with selected strategy.
- **Step 2 — Approve WBNB:** grant router allowance to protect funds.
- **Step 3 — Manual Override:** execute protection from backend guardian.
- UI shows live status (`agent active`, `approved`, `user WBNB`, `demo faucet WBNB`) to avoid blind clicks.

### Why WBNB (not tBNB) for approve?

- `approve()` only works for ERC-20/BEP-20 tokens.
- tBNB is native gas token, so it cannot be approved.
- Router protection logic pulls **WBNB** via `transferFrom`, therefore allowance is required.

## Project Structure

```
lib/
├── core/           # Config & constants
├── models/         # Data models
├── providers/      # Riverpod state management
├── services/       # API services
└── features/       # UI screens
    ├── home/
    └── dashboard/
```

## State Management

Using **Riverpod 2.x** for:
- API state management
- Real-time data updates
- Error handling
- Loading states

## Tech Stack
- Flutter 3.x
- Riverpod (State management)
- Dio (HTTP client)
- fl_chart (Charts)
- web3dart (Blockchain)
- Google Fonts
