import 'package:dio/dio.dart';
import '../core/config.dart';
import '../core/agent_demo.dart';
import '../models/vibe_models.dart';
import '../models/insight_models.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static const String _coinGeckoBaseUrl = 'https://api.coingecko.com/api/v3';

  Future<List<Map<String, dynamic>>> getTokenPresets({int? chainId}) async {
    try {
      final response = await _dio.get(
        '/vibe/token-presets',
        queryParameters: chainId == null ? null : {'chainId': chainId},
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List?) ?? [];
      return items
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    } catch (e) {
      return const <Map<String, dynamic>>[];
    }
  }

  // Get detailed sentiment insights for a token
  Future<Map<String, dynamic>> getInsights(String token,
      {String window = 'Daily'}) async {
    try {
      final response = await _dio.post(
        AppConfig.vibeInsightsEndpoint,
        data: {'token': token.toUpperCase(), 'window': window},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get insights: $e');
    }
  }

  // Get multi-token sentiment dashboard
  Future<Map<String, dynamic>> getMultiTokenSentiment({
    List<String>? tokens,
    String window = 'Daily',
  }) async {
    try {
      final response = await _dio.post(
        AppConfig.vibeMultiEndpoint,
        data: {'tokens': tokens, 'window': window},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get multi-token sentiment: $e');
    }
  }

  Future<List<ChainInfo>> getChains() async {
    try {
      final response = await _dio.get(AppConfig.vibeChainsEndpoint);
      final data = response.data as Map<String, dynamic>;
      final chains = (data['chains'] as List?) ?? [];
      return chains
          .map((e) => ChainInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return _defaultChains;
    }
  }

  static final _defaultChains = [
    ChainInfo(
        id: 'bitcoin',
        name: 'Bitcoin',
        symbol: 'BTC',
        network: 'Bitcoin',
        icon: '₿'),
    ChainInfo(
        id: 'binancecoin',
        name: 'BNB',
        symbol: 'BNB',
        network: 'BNB Chain',
        icon: 'B'),
    ChainInfo(
        id: 'ethereum',
        name: 'Ethereum',
        symbol: 'ETH',
        network: 'Ethereum',
        icon: 'Ξ'),
    ChainInfo(
        id: 'solana',
        name: 'Solana',
        symbol: 'SOL',
        network: 'Solana',
        icon: '◎'),
    ChainInfo(
        id: 'ripple',
        name: 'XRP',
        symbol: 'XRP',
        network: 'XRP Ledger',
        icon: '✕'),
    ChainInfo(
        id: 'dogecoin',
        name: 'Dogecoin',
        symbol: 'DOGE',
        network: 'Dogecoin',
        icon: 'Ð'),
    ChainInfo(id: 'sui', name: 'Sui', symbol: 'SUI', network: 'Sui', icon: '⚡'),
    ChainInfo(
        id: 'tether',
        name: 'Tether',
        symbol: 'USDT',
        network: 'Multi-chain',
        icon: '₮'),
  ];

  Future<VibeCheckResult> checkVibe(String token, String tokenId) async {
    try {
      final cleanToken = token.trim().toUpperCase();
      final cleanTokenId = tokenId.trim().toLowerCase();
      final response = await _dio.post(
        AppConfig.vibeCheckEndpoint,
        data: {'token': cleanToken, 'tokenId': cleanTokenId},
      );
      return VibeCheckResult.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to check vibe: $e');
    }
  }

  Future<Map<String, dynamic>> executeSwap({
    required String userAddress,
    required String tokenAddress,
    required String amount,
  }) async {
    try {
      final response = await _dio.post(
        AppConfig.executeSwapEndpoint,
        data: {
          'userAddress': userAddress,
          'tokenAddress': tokenAddress,
          'amount': amount,
        },
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to execute swap: $e');
    }
  }

  Future<AgentDemoConfig?> getAgentDemoConfig() async {
    final response = await _dio.get(AppConfig.agentDemoConfigEndpoint);
    final data = response.data;
    if (data is Map<String, dynamic> && data['ok'] == true) {
      final cfg = data['config'];
      if (cfg is Map) {
        return AgentDemoConfig.fromJson(cfg.cast<String, dynamic>());
      }
    }

    final err = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'Invalid response';
    throw Exception('Failed to load agent config: $err');
  }

  Future<AgentDemoStatus?> getAgentDemoStatus({
    required String userAddress,
  }) async {
    final response = await _dio.get(
      '/vibe/agent-demo/status',
      queryParameters: {'userAddress': userAddress},
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['ok'] == true) {
      final status = data['status'];
      if (status is Map) {
        return AgentDemoStatus.fromJson(status.cast<String, dynamic>());
      }
    }

    final err = (data is Map && data['error'] != null)
        ? data['error'].toString()
        : 'Invalid response';
    throw Exception('Failed to load agent status: $err');
  }

  Future<AgentDemoTopUpResult> topUpAgentDemoWbnb({
    required String userAddress,
  }) async {
    try {
      final response = await _dio.post(
        '/vibe/agent-demo/topup-wbnb',
        data: {'userAddress': userAddress},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AgentDemoTopUpResult.fromJson(data);
      }
      return const AgentDemoTopUpResult(
        success: false,
        error: 'Invalid response',
      );
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map && resData['error'] != null) {
        return AgentDemoTopUpResult(
          success: false,
          error: resData['error'].toString(),
        );
      }
      return AgentDemoTopUpResult(
        success: false,
        error: e.message ?? 'Failed to top up WBNB',
      );
    }
  }

  Future<Map<String, dynamic>> executeAgentProtection({
    required String userAddress,
    required String amountWbnb,
  }) async {
    try {
      final response = await _dio.post(
        AppConfig.agentDemoExecuteEndpoint,
        data: {
          'userAddress': userAddress,
          'amountWbnb': amountWbnb,
        },
      );
      final data = response.data;
      return (data is Map<String, dynamic>)
          ? data
          : <String, dynamic>{'success': false, 'error': 'Invalid response'};
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map && resData['error'] != null) {
        throw Exception(resData['error'].toString());
      }
      throw Exception('Failed to execute protection: ${e.message ?? e}');
    }
  }

  Future<AgentDemoInjectResult> injectDemoContext({
    required String token,
    String? type,
    String? headline,
    String severity = 'CRITICAL',
    int? ttlMs,
  }) async {
    final secret = AppConfig.demoInjectionSecret.trim();

    try {
      final response = await _dio.post(
        AppConfig.demoInjectEndpoint,
        data: {
          if (secret.isNotEmpty) 'secret': secret,
          'token': token,
          if (type != null && type.isNotEmpty) 'type': type,
          if (headline != null && headline.isNotEmpty) 'headline': headline,
          'severity': severity,
          if (ttlMs != null) 'ttlMs': ttlMs,
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['ok'] == true) {
        final injected = data['injected'];
        if (injected is Map) {
          return AgentDemoInjectResult(
            ok: true,
            context: AgentDemoContext.fromJson(
              injected.cast<String, dynamic>(),
            ),
          );
        }
        return const AgentDemoInjectResult(ok: true);
      }

      final err = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Invalid response';
      return AgentDemoInjectResult(ok: false, error: err);
    } on DioException catch (e) {
      final resData = e.response?.data;
      if (resData is Map && resData['error'] != null) {
        return AgentDemoInjectResult(
          ok: false,
          error: resData['error'].toString(),
        );
      }
      return AgentDemoInjectResult(
        ok: false,
        error: e.message ?? 'Failed to inject demo context',
      );
    }
  }

  Future<AgentDemoContext?> getDemoContext() async {
    try {
      final response = await _dio.get(AppConfig.demoContextEndpoint);
      final data = response.data;
      if (data is Map<String, dynamic> && data['ok'] == true) {
        final context = data['context'];
        if (context is Map) {
          return AgentDemoContext.fromJson(context.cast<String, dynamic>());
        }
        return null;
      }

      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      return null;
    }
  }

  Future<List<TxHistoryItem>> getTxHistory(
      {required String userAddress, int limit = 50}) async {
    try {
      final response = await _dio.get(
        AppConfig.txHistoryEndpoint,
        queryParameters: {'userAddress': userAddress, 'limit': limit},
      );
      final data = response.data;
      final items =
          (data is Map<String, dynamic>) ? (data['items'] as List? ?? []) : [];
      return items
          .map((e) => TxHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load tx history: $e');
    }
  }

  Future<List<PriceData>> getMarketPrices({List<String>? ids}) async {
    final resolvedIds = (ids == null || ids.isEmpty)
        ? const ['bitcoin', 'binancecoin', 'ethereum', 'tether']
        : ids;

    try {
      final response = await _dio.get(
        AppConfig.marketPricesEndpoint,
        queryParameters: {
          'ids': resolvedIds.join(','),
        },
      );

      final data = response.data;
      final items =
          (data is Map<String, dynamic>) ? (data['items'] as List? ?? []) : [];
      return items
          .whereType<Map>()
          .map((e) => PriceData.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      return await _getMarketPricesFromCoinGecko(resolvedIds);
    }
  }

  Future<List<PriceData>> _getMarketPricesFromCoinGecko(
      List<String> ids) async {
    final dio = Dio(BaseOptions(
      baseUrl: _coinGeckoBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
    ));

    final response = await dio.get(
      '/simple/price',
      queryParameters: {
        'ids': ids.join(','),
        'vs_currencies': 'usd',
        'include_24hr_vol': true,
        'include_24hr_change': true,
      },
    );

    final data = response.data;
    if (data is! Map) return const <PriceData>[];

    final out = <PriceData>[];
    for (final id in ids) {
      final row = data[id];
      if (row is! Map) continue;
      final usd = row['usd'];
      if (usd is! num) continue;

      out.add(
        PriceData(
          token: id,
          price: usd.toDouble(),
          volume24h: (row['usd_24h_vol'] is num)
              ? (row['usd_24h_vol'] as num).toDouble()
              : 0,
          priceChange24h: (row['usd_24h_change'] is num)
              ? (row['usd_24h_change'] as num).toDouble()
              : 0,
        ),
      );
    }
    return out;
  }
}
