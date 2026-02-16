class Web3Injected {
  bool get isAvailable => false;

  Future<List<String>> requestAccounts() async {
    throw UnsupportedError('Injected wallet is not available on this platform.');
  }

  Future<List<String>> getAccounts() async {
    throw UnsupportedError('Injected wallet is not available on this platform.');
  }

  Future<int?> requestChainId() async => null;

  Future<void> switchChain(int chainId) async {
    throw UnsupportedError('Injected wallet is not available on this platform.');
  }

  Future<void> addChain(Map<String, dynamic> params) async {
    throw UnsupportedError('Injected wallet is not available on this platform.');
  }

  Future<String?> sendTransaction(Map<String, dynamic> tx) async {
    throw UnsupportedError('Injected wallet is not available on this platform.');
  }
}
