class AppConfig {
  static const String walletConnectProjectId = String.fromEnvironment(
    'WALLETCONNECT_PROJECT_ID',
    defaultValue: '',
  );

  static String get _apiOrigin {
    const env = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (env.isNotEmpty) return env;

    // Default to the deployed backend for all platforms (Web + Mobile).
    return 'https://vibeguard-ai-production.up.railway.app';
  }

  static String get apiBaseUrl {
    final origin = _apiOrigin.trim();
    if (origin.isEmpty) return '/api';

    // Prevent accidental double '/api' when API_BASE_URL is already set to an API root.
    final normalized =
        origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;
    if (normalized.endsWith('/api')) return normalized;
    return '$normalized/api';
  }

  static const String vibeCheckEndpoint = '/vibe/check';
  static const String executeSwapEndpoint = '/vibe/execute-swap';

  // Agent demo endpoints (BSC Testnet wiring)
  static const String agentDemoConfigEndpoint = '/vibe/agent-demo/config';
  static const String agentDemoExecuteEndpoint =
      '/vibe/agent-demo/execute-protection';
  static const String demoInjectEndpoint = '/vibe/demo/inject';
  static const String demoContextEndpoint = '/vibe/demo/context';
  static const String demoInjectionSecret = String.fromEnvironment(
    'DEMO_INJECTION_SECRET',
    defaultValue: '',
  );

  // Endpoints for enhanced Cryptoracle data
  static const String vibeInsightsEndpoint = '/vibe/insights';
  static const String vibeMultiEndpoint = '/vibe/multi';
  static const String vibeChainsEndpoint = '/vibe/chains';

  static const String marketPricesEndpoint = '/vibe/prices';

  static const String marketIntelEndpoint = '/vibe/market-intel';

  static const String txHistoryEndpoint = '/vibe/tx-history';

  static const String rpcUrl = String.fromEnvironment(
    'RPC_URL',

    defaultValue: 'https://bsc-testnet-rpc.publicnode.com',
  );

  // Default to BSC Testnet (97). Override via --dart-define=CHAIN_ID=56 if needed.
  static const int chainId = int.fromEnvironment('CHAIN_ID', defaultValue: 97);

  static String get explorerTxBaseUrl {
    const env =
        String.fromEnvironment('EXPLORER_TX_BASE_URL', defaultValue: '');
    if (env.isNotEmpty) return env;

    if (chainId == 56) return 'https://bscscan.com/tx/';
    if (chainId == 97) return 'https://testnet.bscscan.com/tx/';
    return '';
  }
}
