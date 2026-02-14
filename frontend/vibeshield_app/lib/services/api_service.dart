import 'package:dio/dio.dart';
import '../core/config.dart';
import '../models/vibe_models.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static const String _coinGeckoBaseUrl = 'https://api.coingecko.com/api/v3';

  Future<VibeCheckResult> checkVibe(String token, String tokenId) async {
    try {
      final response = await _dio.post(
        AppConfig.vibeCheckEndpoint,
        data: {'token': token, 'tokenId': tokenId},
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

  Future<List<TxHistoryItem>> getTxHistory({required String userAddress, int limit = 50}) async {
    try {
      final response = await _dio.get(
        AppConfig.txHistoryEndpoint,
        queryParameters: {'userAddress': userAddress, 'limit': limit},
      );
      final data = response.data;
      final items = (data is Map<String, dynamic>) ? (data['items'] as List? ?? []) : [];
      return items.map((e) => TxHistoryItem.fromJson(e as Map<String, dynamic>)).toList();
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
      final items = (data is Map<String, dynamic>) ? (data['items'] as List? ?? []) : [];
      return items
          .whereType<Map>()
          .map((e) => PriceData.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {

      return await _getMarketPricesFromCoinGecko(resolvedIds);
    }
  }

  Future<List<PriceData>> _getMarketPricesFromCoinGecko(List<String> ids) async {
    final dio = Dio(BaseOptions(
      baseUrl: _coinGeckoBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
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
          volume24h: (row['usd_24h_vol'] is num) ? (row['usd_24h_vol'] as num).toDouble() : 0,
          priceChange24h: (row['usd_24h_change'] is num) ? (row['usd_24h_change'] as num).toDouble() : 0,
        ),
      );
    }
    return out;
  }
}
