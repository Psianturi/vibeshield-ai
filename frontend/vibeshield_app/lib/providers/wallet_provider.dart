import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallet_service.dart';

class WalletState {
  final bool isConnected;
  final String? address;
  final bool isLoading;
  final String? error;

  WalletState({
    this.isConnected = false,
    this.address,
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    bool? isConnected,
    String? address,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      isConnected: isConnected ?? this.isConnected,
      address: address ?? this.address,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  String get shortAddress {
    if (address == null || address!.length < 10) return address ?? '';
    return '${address!.substring(0, 6)}...${address!.substring(address!.length - 4)}';
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final WalletService _walletService;

  WalletNotifier(this._walletService) : super(WalletState()) {
    _init();
  }

  Future<void> _init() async {
    await _walletService.init();
    if (_walletService.isConnected) {
      state = state.copyWith(
        isConnected: true,
        address: _walletService.address,
      );
    }
  }

  Future<void> connect() async {
    await _connectWith(_walletService.connect);
  }

  Future<void> connectInjected() async {
    await _connectWith(_walletService.connectInjected);
  }

  Future<void> connectWalletConnect() async {
    await _connectWith(_walletService.connectWalletConnect);
  }

  Future<void> _connectWith(Future<String?> Function() connectFn) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final address = await connectFn();

      if (address != null) {
        state = state.copyWith(
          isConnected: true,
          address: address,
          isLoading: false,
        );
      } else {
        final reason = _walletService.lastError;
        state = state.copyWith(
          isLoading: false,
          error: (reason == null || reason.isEmpty)
              ? 'Wallet connection was not approved (or timed out).'
              : reason,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> disconnect() async {
    await _walletService.disconnect();
    state = WalletState();
  }

  Future<String?> signMessage(String message) async {
    try {
      return await _walletService.signMessage(message);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

final walletServiceProvider = Provider((ref) => WalletService.instance);

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.read(walletServiceProvider));
});
