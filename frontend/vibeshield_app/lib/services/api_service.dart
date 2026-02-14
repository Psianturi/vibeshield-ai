import 'package:dio/dio.dart';
import '../core/config.dart';
import '../models/vibe_models.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

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
    try {
      final response = await _dio.get(
        AppConfig.marketPricesEndpoint,
        queryParameters: {
          if (ids != null && ids.isNotEmpty) 'ids': ids.join(','),
        },
      );

      final data = response.data;
      final items = (data is Map<String, dynamic>) ? (data['items'] as List? ?? []) : [];
      return items
          .whereType<Map>()
          .map((e) => PriceData.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      throw Exception('Failed to load market prices: $e');
    }
  }
}
