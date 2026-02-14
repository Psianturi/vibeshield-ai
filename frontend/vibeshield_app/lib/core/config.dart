import 'package:flutter/foundation.dart';

class AppConfig {
  static String get _apiOrigin {
    const env = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (env.isNotEmpty) return env;


    if (kIsWeb) return 'https://vibeguard-ai-production.up.railway.app';

    if (kReleaseMode) return 'https://vibeguard-ai-production.up.railway.app';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator host loopback
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
        return 'http://localhost:3000';
      default:
        return 'http://localhost:3000';
    }
  }

  static String get apiBaseUrl => '$_apiOrigin/api';
  static const String vibeCheckEndpoint = '/vibe/check';
  static const String executeSwapEndpoint = '/vibe/execute-swap';

  static const String marketPricesEndpoint = '/vibe/prices';

  static const String txHistoryEndpoint = '/vibe/tx-history';
  
  static const String rpcUrl = String.fromEnvironment(
    'RPC_URL',
    defaultValue: 'https://bsc-dataseed.binance.org/',
  );

  static const int chainId = int.fromEnvironment('CHAIN_ID', defaultValue: 56);

  static String get explorerTxBaseUrl {
    const env = String.fromEnvironment('EXPLORER_TX_BASE_URL', defaultValue: '');
    if (env.isNotEmpty) return env;

    if (chainId == 11155111) return 'https://sepolia.etherscan.io/tx/';
    if (chainId == 56) return 'https://bscscan.com/tx/';
    return '';
  }
}
