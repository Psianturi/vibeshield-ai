// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_util' as js_util;

class Web3Injected {
  Object? get _ethereum {
    try {
      return js_util.getProperty(js_util.globalThis, 'ethereum');
    } catch (_) {
      return null;
    }
  }

  bool get isAvailable => _ethereum != null;

  Future<dynamic> _request(String method, [List<dynamic>? params]) async {
    final ethereum = _ethereum;
    if (ethereum == null) {
      throw UnsupportedError('Injected wallet not found.');
    }

    final payload = <String, dynamic>{'method': method};
    if (params != null) {
      payload['params'] = params;
    }

    return js_util.promiseToFuture(
      js_util.callMethod(ethereum, 'request', [js_util.jsify(payload)]),
    );
  }

  Future<List<String>> requestAccounts() async {
    final result = await _request('eth_requestAccounts');
    if (result is List) {
      return result.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  Future<int?> requestChainId() async {
    final result = await _request('eth_chainId');
    if (result is String) {
      final v = result.trim();
      if (v.startsWith('0x')) {
        return int.tryParse(v.substring(2), radix: 16);
      }
      return int.tryParse(v);
    }
    return null;
  }

  Future<void> switchChain(int chainId) async {
    await _request('wallet_switchEthereumChain', [
      {'chainId': _toHexChainId(chainId)}
    ]);
  }

  Future<void> addChain(Map<String, dynamic> params) async {
    await _request('wallet_addEthereumChain', [params]);
  }

  Future<String?> sendTransaction(Map<String, dynamic> tx) async {
    final result = await _request('eth_sendTransaction', [tx]);
    return result as String?;
  }

  String _toHexChainId(int chainId) => '0x${chainId.toRadixString(16)}';
}
