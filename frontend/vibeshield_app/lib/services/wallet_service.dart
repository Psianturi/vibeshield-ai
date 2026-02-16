import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/agent_demo.dart';
import '../core/config.dart';
import 'web3_injected.dart';

class WalletService {
  static WalletService? _instance;

  ReownAppKit? _appKit;
  SessionData? _session;
  String? _currentAddress;
  int? _sessionChainId;
  String? _lastError;
  String? _resolvedProjectId;
  bool _usingInjected = false;
  final Web3Injected _injected = Web3Injected();

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;
  final _wcUriController = StreamController<Uri>.broadcast();
  Stream<Uri> get wcUriStream => _wcUriController.stream;

  WalletService._();

  static WalletService get instance {
    _instance ??= WalletService._();
    return _instance!;
  }

  bool get isConnected =>
      _currentAddress != null && (_session != null || _usingInjected);
  String? get address => _currentAddress;
  int? get chainId => _sessionChainId;
  String? get lastError => _lastError;
  bool get hasInjected => _injected.isAvailable;
  bool get isUsingInjected => _usingInjected;

  Future<void> init() async {
    if (_appKit != null) return;

    try {
      _lastError = null;
      final projectId = await _getProjectId();

      _appKit = await ReownAppKit.createInstance(
        projectId: projectId,
        metadata: const PairingMetadata(
          name: 'VibeShield AI',
          description: 'Crypto Portfolio Guardian',
          url: 'https://vibeshield.ai',
          icons: ['https://vibeshield.ai/icon.png'],
        ),
      );

      _appKit!.onSessionConnect.subscribe(_onSessionConnect);
      _appKit!.onSessionDelete.subscribe(_onSessionDelete);

      await _appKit!.init();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Reown AppKit init error: $e');
    }
  }

  Future<String> _getProjectId() async {
    final existing =
        (_resolvedProjectId ?? AppConfig.walletConnectProjectId).trim();
    if (existing.isNotEmpty) {
      _resolvedProjectId = existing;
      return existing;
    }

    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

      final apiBaseUrl = AppConfig.apiBaseUrl.trim();
      final parsed = Uri.tryParse(apiBaseUrl);
      final origin = (parsed != null && parsed.hasScheme && parsed.hasAuthority)
          ? '${parsed.scheme}://${parsed.authority}'
          : '';

      String joinUrl(String base, String path) {
        final b =
            base.endsWith('/') ? base.substring(0, base.length - 1) : base;
        return '$b$path';
      }

      final candidates = <String>{
        if (apiBaseUrl.isNotEmpty) joinUrl(apiBaseUrl, '/vibe/public-config'),
        if (origin.isNotEmpty) joinUrl(origin, '/api/vibe/public-config'),
        if (origin.isNotEmpty) joinUrl(origin, '/vibe/public-config'),
      }.toList();

      int? lastStatus;
      for (final url in candidates) {
        try {
          final res = await dio.get(
            url,
            options: Options(
              validateStatus: (code) =>
                  code != null && code >= 200 && code < 500,
            ),
          );
          lastStatus = res.statusCode;

          if (res.statusCode != null &&
              res.statusCode! >= 200 &&
              res.statusCode! < 300) {
            final data = res.data;
            if (data is Map) {
              final pid =
                  (data['walletConnectProjectId'] ?? '').toString().trim();
              if (pid.isNotEmpty) {
                _resolvedProjectId = pid;
                return pid;
              }
            }
          }
        } catch (_) {
          // try next candidate
        }
      }

      debugPrint(
        'WalletConnect projectId fetch failed (status: ${lastStatus ?? 'n/a'}). Tried: ${candidates.join(', ')}',
      );
    } catch (e) {
      debugPrint('WalletConnect projectId fetch failed: $e');
    }

    throw Exception('WalletConnect Project ID is not configured');
  }

  Future<String?> connect() async {
    try {
      _lastError = null;
      await init();

      if (kIsWeb && _injected.isAvailable) {
        try {
          final addr = await _attemptInjectedConnect();
          if (addr != null) return addr;
          return null;
        } catch (e) {
          _lastError = e.toString();
          debugPrint('[wallet] injected connect error: $_lastError');
          return null;
        }
      }

      return await connectWalletConnect();
    } on TimeoutException {
      _lastError =
          'WalletConnect approval timed out. Please open your wallet app and approve the connection, then try again.';
      debugPrint('WalletConnect error: $_lastError');
      _session = null;
      _currentAddress = null;
      _sessionChainId = null;
      return null;
    } catch (e) {
      final raw = e.toString();
      debugPrint('[wallet] connect error: $raw');
      if (raw.contains('JsonRpcError') &&
          raw.contains('code: 4001') &&
          raw.toLowerCase().contains('reject')) {
        _lastError =
            'Connection was rejected in your wallet. Please open your wallet app and approve the connection request.';
      } else if (raw.toLowerCase().contains('not supported') ||
          raw.toLowerCase().contains('unsupported') ||
          (raw.toLowerCase().contains('jaringan') &&
              raw.toLowerCase().contains('didukung'))) {
        _lastError =
            'Network is not supported in the wallet. Please add/switch to BSC Testnet (chainId 97) in your wallet and try again.';
      } else {
        _lastError = raw;
      }
      debugPrint('WalletConnect error: $e');
      _session = null;
      _currentAddress = null;
      _sessionChainId = null;
      return null;
    }
  }

  Future<String?> connectInjected() async {
    _lastError = null;
    await init();
    return _attemptInjectedConnect();
  }

  Future<String?> connectWalletConnect() async {
    _lastError = null;
    await init();

    if (_appKit == null) {
      throw Exception(_lastError ?? 'Reown AppKit not initialized');
    }

    if (_session != null) {
      return _currentAddress;
    }

    final requiredChains = const ['eip155:56'];
    final optionalChains = (AppConfig.chainId == 56)
        ? const <String>[]
        : ['eip155:${AppConfig.chainId}'];

    return _attemptWalletConnect(
      requiredChains: requiredChains,
      optionalChains: optionalChains,
    );
  }

  Future<String?> _attemptInjectedConnect() async {
    if (!_injected.isAvailable) {
      _lastError =
          'MetaMask not detected. Install/enable the MetaMask extension and refresh the page.';
      return null;
    }
    debugPrint('[wallet] web injected connect');

    final accounts = await _injected.requestAccounts();
    if (accounts.isEmpty) {
      _lastError = 'No accounts returned by wallet.';
      return null;
    }

    _currentAddress = accounts.first;
    _sessionChainId = await _injected.requestChainId();
    _session = null;
    _usingInjected = true;
    debugPrint(
      '[wallet] injected account=${_currentAddress ?? 'n/a'} chainId=${_sessionChainId ?? 'n/a'}',
    );

    if (_sessionChainId != AppConfig.chainId) {
      debugPrint(
        '[wallet] injected switch chain from ${_sessionChainId ?? 'n/a'} to ${AppConfig.chainId}',
      );
      final ok = await _ensureChain(AppConfig.chainId);
      if (!ok) {
        _lastError = _lastError ??
            'Network is not supported in the wallet. Please add/switch to the configured network and try again.';
        debugPrint('[wallet] injected chain switch failed: $_lastError');
        _usingInjected = false;
        _currentAddress = null;
        _sessionChainId = null;
        return null;
      }
      _sessionChainId = AppConfig.chainId;
    }

    _connectionController.add(true);
    return _currentAddress;
  }

  Future<String?> _attemptWalletConnect({
    required List<String> requiredChains,
    List<String> optionalChains = const [],
  }) async {
      debugPrint(
        '[wallet] connect: required=$requiredChains optional=$optionalChains',
      );
      const requiredMethods = [
        'eth_sendTransaction',
        'personal_sign',
        'eth_chainId',
        'eth_accounts',
      ];
      const optionalMethods = [
        ...requiredMethods,
        'wallet_switchEthereumChain',
        'wallet_addEthereumChain',
      ];
      const events = ['chainChanged', 'accountsChanged'];

      final requiredNamespaces = {
        'eip155': RequiredNamespace(
          chains: requiredChains,
          methods: requiredMethods,
          events: events,
        ),
      };

      final optionalNamespaces = optionalChains.isEmpty
          ? null
          : {
              'eip155': RequiredNamespace(
                chains: optionalChains,
                methods: optionalMethods,
                events: events,
              ),
            };

      final ConnectResponse response = await _appKit!.connect(
        requiredNamespaces: requiredNamespaces,
        optionalNamespaces: optionalNamespaces,
      );

      final Uri? uri = response.uri;
      if (uri != null) {
        debugPrint('[wallet] wc uri: $uri');
        if (kIsWeb) {
          _wcUriController.add(uri);
        } else {
          // Launch wc: URI first to let Android route to the correct wallet.
          final encoded = Uri.encodeComponent(uri.toString());
          final candidates = <Uri>[
            uri,
            Uri.parse('metamask://wc?uri=$encoded'),
            Uri.parse('trust://wc?uri=$encoded'),
          ];

          bool launched = false;
          for (final candidate in candidates) {
            try {
              final ok = await launchUrl(
                candidate,
                mode: LaunchMode.externalApplication,
              );
              if (ok) {
                launched = true;
                break;
              }
            } catch (_) {
              // try next
            }
          }

          if (!launched) {
            throw Exception(
              'No compatible wallet app found. Install a WalletConnect-compatible wallet and try again.',
            );
          }
        }
      }

      _session =
          await response.session.future.timeout(const Duration(minutes: 2));
      debugPrint('[wallet] session approved');

      final accounts = _session?.namespaces['eip155']?.accounts ?? [];
      if (accounts.isEmpty) return null;

      final first = accounts.first;
      final parts = first.split(':');
      _sessionChainId = (parts.length >= 2) ? int.tryParse(parts[1]) : null;
      _currentAddress = parts.isNotEmpty ? parts.last : null;
      debugPrint(
        '[wallet] account=${_currentAddress ?? 'n/a'} chainId=${_sessionChainId ?? 'n/a'}',
      );

      if (_currentAddress == null || _currentAddress!.isEmpty) {
        _lastError = 'WalletConnect session approved, but no address found.';
        await disconnect();
        return null;
      }

      if (_sessionChainId != AppConfig.chainId) {
        debugPrint(
          '[wallet] switch chain from ${_sessionChainId ?? 'n/a'} to ${AppConfig.chainId}',
        );
        final ok = await _ensureChain(AppConfig.chainId);
        if (!ok) {
          _lastError = _lastError ??
              'Network is not supported in the wallet. Please add/switch to the configured network and try again.';
          debugPrint('[wallet] chain switch failed: $_lastError');
          await disconnect();
          return null;
        }
        _sessionChainId = AppConfig.chainId;
      }

      _connectionController.add(true);
      return _currentAddress;
    }

    }

  Future<void> disconnect() async {
    if (_session != null && _appKit != null) {
      try {
        final coreError = Errors.getSdkError(Errors.USER_DISCONNECTED);
        await _appKit!.disconnectSession(
          topic: _session!.topic,
          reason: ReownSignError(
            code: coreError.code,
            message: coreError.message,
            data: coreError.data,
          ),
        );
      } catch (e) {
        debugPrint('Disconnect error: $e');
      }
    }
    _session = null;
    _currentAddress = null;
    _sessionChainId = null;
    _lastError = null;
    _usingInjected = false;
    _connectionController.add(false);
  }

  void _onSessionConnect(SessionConnect? event) {
    if (event != null) {
      _session = event.session;
      final accounts = _session!.namespaces['eip155']?.accounts ?? [];
      if (accounts.isNotEmpty) {
        final first = accounts.first;
        final parts = first.split(':');
        _sessionChainId = (parts.length >= 2) ? int.tryParse(parts[1]) : null;
        _currentAddress = parts.isNotEmpty ? parts.last : null;
        _connectionController.add(true);
      }
    }
  }

  void _onSessionDelete(SessionDelete? event) {
    _session = null;
    _currentAddress = null;
    _connectionController.add(false);
  }

  Future<bool> _ensureChain(int chainId) async {
    if (_usingInjected) {
      try {
        await _injected.switchChain(chainId);
        final active = await _injected.requestChainId();
        if (active != null && active != chainId) {
          _lastError = 'Wallet remained on chainId $active after switch request.';
          debugPrint('[wallet] injected chain still $active after switch');
          return false;
        }
        return true;
      } catch (e) {
        final raw = e.toString();
        debugPrint('[wallet] injected switch chain error: $raw');
        final needsAdd = raw.contains('4902') ||
            raw.toLowerCase().contains('unrecognized') ||
            raw.toLowerCase().contains('unknown chain');

        final chainParams = _chainParams(chainId);
        if (!needsAdd || chainParams == null) {
          _lastError = raw;
          return false;
        }

        try {
          await _injected.addChain(chainParams);
          await _injected.switchChain(chainId);
          final active = await _injected.requestChainId();
          if (active != null && active != chainId) {
            _lastError = 'Wallet remained on chainId $active after add/switch.';
            debugPrint('[wallet] injected chain still $active after add/switch');
            return false;
          }
          return true;
        } catch (err) {
          _lastError = err.toString();
          debugPrint('[wallet] injected add/switch chain failed: $_lastError');
          return false;
        }
      }
    }

    if (_appKit == null || _session == null) return false;

    final requestChainId = _sessionChainId ?? AppConfig.chainId;
    final hexChainId = _toHexChainId(chainId);
    final chainParams = _chainParams(chainId);

    try {
      debugPrint('[wallet] request switch chain to $chainId');
      await _appKit!.request(
        topic: _session!.topic,
        chainId: 'eip155:$requestChainId',
        request: SessionRequestParams(
          method: 'wallet_switchEthereumChain',
          params: [
            {'chainId': hexChainId}
          ],
        ),
      );
      final active = await _readChainId(requestChainId);
      if (active != null && active != chainId) {
        _lastError = 'Wallet remained on chainId $active after switch request.';
        debugPrint('[wallet] chain still $active after switch');
        return false;
      }
      return true;
    } catch (e) {
      final raw = e.toString();
      debugPrint('[wallet] switch chain error: $raw');
      final needsAdd = raw.contains('4902') ||
          raw.toLowerCase().contains('unrecognized') ||
          raw.toLowerCase().contains('unknown chain');

      if (!needsAdd || chainParams == null) {
        _lastError = raw;
        return false;
      }

      try {
        debugPrint('[wallet] request add chain $chainId');
        await _appKit!.request(
          topic: _session!.topic,
          chainId: 'eip155:$requestChainId',
          request: SessionRequestParams(
            method: 'wallet_addEthereumChain',
            params: [chainParams],
          ),
        );

        debugPrint('[wallet] request switch chain to $chainId (after add)');
        await _appKit!.request(
          topic: _session!.topic,
          chainId: 'eip155:$requestChainId',
          request: SessionRequestParams(
            method: 'wallet_switchEthereumChain',
            params: [
              {'chainId': hexChainId}
            ],
          ),
        );
        final active = await _readChainId(requestChainId);
        if (active != null && active != chainId) {
          _lastError = 'Wallet remained on chainId $active after add/switch.';
          debugPrint('[wallet] chain still $active after add/switch');
          return false;
        }
        return true;
      } catch (err) {
        _lastError = err.toString();
        debugPrint('[wallet] add/switch chain failed: $_lastError');
        return false;
      }
    }
  }

  Future<int?> _readChainId(int requestChainId) async {
    if (_usingInjected) {
      return _injected.requestChainId();
    }

    if (_appKit == null || _session == null) return null;

    try {
      final result = await _appKit!.request(
        topic: _session!.topic,
        chainId: 'eip155:$requestChainId',
        request: SessionRequestParams(
          method: 'eth_chainId',
          params: const [],
        ),
      );

      if (result is String) {
        return int.tryParse(result.replaceFirst('0x', ''), radix: 16);
      }
      return null;
    } catch (e) {
      debugPrint('[wallet] eth_chainId error: $e');
      return null;
    }
  }

  String _toHexChainId(int chainId) => '0x${chainId.toRadixString(16)}';

  String _normalizeExplorerBase(String url) {
    var out = url.trim();
    if (out.endsWith('/tx/')) out = out.substring(0, out.length - 4);
    if (out.endsWith('/tx')) out = out.substring(0, out.length - 3);
    return out;
  }

  Map<String, dynamic>? _chainParams(int chainId) {
    final rpcUrl = AppConfig.rpcUrl.trim();
    final explorerBase = _normalizeExplorerBase(AppConfig.explorerTxBaseUrl);

    if (chainId == 97) {
      return {
        'chainId': _toHexChainId(chainId),
        'chainName': 'BSC Testnet',
        'rpcUrls': rpcUrl.isNotEmpty
            ? [rpcUrl]
            : ['https://bsc-testnet-rpc.publicnode.com'],
        'nativeCurrency': {
          'name': 'tBNB',
          'symbol': 'tBNB',
          'decimals': 18,
        },
        'blockExplorerUrls': explorerBase.isNotEmpty
            ? [explorerBase]
            : ['https://testnet.bscscan.com'],
      };
    }

    if (chainId == 56) {
      return {
        'chainId': _toHexChainId(chainId),
        'chainName': 'BNB Chain',
        'rpcUrls': rpcUrl.isNotEmpty
            ? [rpcUrl]
            : ['https://bsc-dataseed.binance.org'],
        'nativeCurrency': {
          'name': 'BNB',
          'symbol': 'BNB',
          'decimals': 18,
        },
        'blockExplorerUrls': explorerBase.isNotEmpty
            ? [explorerBase]
            : ['https://bscscan.com'],
      };
    }

    return null;
  }

  Future<String?> signMessage(String message) async {
    if (_session == null || _appKit == null || _currentAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final cid = _sessionChainId ?? AppConfig.chainId;
      final signature = await _appKit!.request(
        topic: _session!.topic,
        chainId: 'eip155:$cid',
        request: SessionRequestParams(
          method: 'personal_sign',
          params: [message, _currentAddress],
        ),
      );

      return signature as String?;
    } catch (e) {
      debugPrint('Sign message error: $e');
      return null;
    }
  }

  Future<String?> sendTransaction({
    required String to,
    required String data,
    BigInt? valueWei,
  }) async {
    if ((_session == null && !_usingInjected) ||
        _currentAddress == null ||
        (_appKit == null && !_usingInjected)) {
      throw Exception('Wallet not connected');
    }

    final tx = <String, dynamic>{
      'from': _currentAddress,
      'to': to,
      'data': data,
    };

    if (valueWei != null) {
      tx['value'] = AgentDemoTxBuilder.toHexQuantity(valueWei);
    }

    try {
      debugPrint('[wallet] send tx to=$to valueWei=${valueWei ?? BigInt.zero}');
      final result = _usingInjected
          ? await _injected.sendTransaction(tx)
          : await _appKit!
              .request(
                topic: _session!.topic,
                chainId: 'eip155:${_sessionChainId ?? AppConfig.chainId}',
                request: SessionRequestParams(
                  method: 'eth_sendTransaction',
                  params: [tx],
                ),
              )
              .timeout(const Duration(seconds: 90));
      debugPrint('[wallet] send tx result: $result');
      return result as String?;
    } on TimeoutException {
      _lastError = 'Wallet transaction timed out.';
      debugPrint('[wallet] send tx timeout');
      return null;
    } catch (e) {
      debugPrint('[wallet] send tx error: $e');
      _lastError = e.toString();
      return null;
    }
  }

  Future<bool> openWalletApp() async {
    if (kIsWeb) return false;

    final candidates = <Uri>[
      Uri.parse('metamask://'),
      Uri.parse('trust://'),
    ];

    for (final uri in candidates) {
      try {
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (ok) return true;
      } catch (_) {
        // ignore and try next
      }
    }
    return false;
  }

  void dispose() {
    _appKit?.onSessionConnect.unsubscribe(_onSessionConnect);
    _appKit?.onSessionDelete.unsubscribe(_onSessionDelete);
    _connectionController.close();
    _wcUriController.close();
  }
}
