# VibeGuard AI - Frontend

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
