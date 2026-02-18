import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/insight_models.dart';
import '../services/api_service.dart';


final apiServiceProvider = Provider<ApiService>((ref) => ApiService());


class InsightsState {
  final bool isLoading;
  final Map<String, dynamic>? data;
  final String? error;

  InsightsState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  InsightsState copyWith({
    bool? isLoading,
    Map<String, dynamic>? data,
    String? error,
  }) {
    return InsightsState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error,
    );
  }
}

class InsightsNotifier extends StateNotifier<InsightsState> {
  final ApiService _api;

  InsightsNotifier(this._api) : super(InsightsState());

  Future<void> fetchInsights(String token, {String window = 'Daily'}) async {
    state = InsightsState(isLoading: true);
    try {
      final data = await _api.getInsights(token, window: window);
      state = InsightsState(data: data);
    } catch (e) {
      state = InsightsState(error: e.toString());
    }
  }
}


final insightsProvider = StateNotifierProvider<InsightsNotifier, InsightsState>((ref) {
  return InsightsNotifier(ref.watch(apiServiceProvider));
});

// State for multi-token dashboard
class MultiTokenState {
  final bool isLoading;
  final Map<String, dynamic>? tokens;
  final String? error;
  final String? source;
  final int? updatedAt;
  final Map<String, dynamic>? stats;

  MultiTokenState({
    this.isLoading = false,
    this.tokens,
    this.error,
    this.source,
    this.updatedAt,
    this.stats,
  });

  MultiTokenState copyWith({
    bool? isLoading,
    Map<String, dynamic>? tokens,
    String? error,
    String? source,
    int? updatedAt,
    Map<String, dynamic>? stats,
  }) {
    return MultiTokenState(
      isLoading: isLoading ?? this.isLoading,
      tokens: tokens ?? this.tokens,
      error: error,
      source: source ?? this.source,
      updatedAt: updatedAt ?? this.updatedAt,
      stats: stats ?? this.stats,
    );
  }
}

class MultiTokenNotifier extends StateNotifier<MultiTokenState> {
  final ApiService _api;

  MultiTokenNotifier(this._api) : super(MultiTokenState());

  Future<void> fetchAll({String window = 'Daily'}) async {
    state = MultiTokenState(isLoading: true);
    try {
      final data = await _api.getMultiTokenSentiment(window: window);
      state = MultiTokenState(
        tokens: data['tokens'],
        source: data['source'] as String?,
        updatedAt: data['updatedAt'] as int?,
        stats: data['stats'] as Map<String, dynamic>?,
      );
    } catch (e) {
      state = MultiTokenState(error: e.toString());
    }
  }
}

// Provider for multi-token
final multiTokenProvider = StateNotifierProvider<MultiTokenNotifier, MultiTokenState>((ref) {
  return MultiTokenNotifier(ref.watch(apiServiceProvider));
});

// Provider for chains
final chainsProvider = FutureProvider<List<ChainInfo>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getChains();
});

final marketIntelProvider = FutureProvider.autoDispose<MarketIntel>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getMarketIntel();
});
