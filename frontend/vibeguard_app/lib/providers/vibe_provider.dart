import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/vibe_models.dart';

final apiServiceProvider = Provider((ref) => ApiService());

final vibeCheckProvider = FutureProvider.family<VibeCheckResult, Map<String, String>>((ref, params) async {
  final apiService = ref.read(apiServiceProvider);
  return await apiService.checkVibe(params['token']!, params['tokenId']!);
});

class VibeState {
  final VibeCheckResult? result;
  final bool isLoading;
  final String? error;

  VibeState({this.result, this.isLoading = false, this.error});

  VibeState copyWith({VibeCheckResult? result, bool? isLoading, String? error}) {
    return VibeState(
      result: result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class VibeNotifier extends StateNotifier<VibeState> {
  final ApiService apiService;

  VibeNotifier(this.apiService) : super(VibeState());

  Future<void> checkVibe(String token, String tokenId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await apiService.checkVibe(token, tokenId);
      state = state.copyWith(result: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}

final vibeNotifierProvider = StateNotifierProvider<VibeNotifier, VibeState>((ref) {
  return VibeNotifier(ref.read(apiServiceProvider));
});
