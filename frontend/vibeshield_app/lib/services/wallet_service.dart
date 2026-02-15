import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config.dart';
import '../core/agent_demo.dart';

class WalletService {
  static WalletService? _instance;
  ReownAppKit? _appKit;
  SessionData? _session;
  String? _currentAddress;
  String? _lastError;
  String? _resolvedProjectId;

  // Stream controller for connection state changes
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  WalletService._();

  static WalletService get instance {
    _instance ??= WalletService._();
    return _instance!;
  }

  bool get isConnected => _session != null && _currentAddress != null;
  String? get address => _currentAddress;
  String? get lastError => _lastError;

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

      // Listen to session events
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
          // Try next candidate.
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

      if (_appKit == null) {
        throw Exception(_lastError ?? 'Reown AppKit not initialized');
      }

      // Check if already connected
      if (_session != null) {
        return _currentAddress;
      }

      // Create connection
      final ConnectResponse response = await _appKit!.connect(
        requiredNamespaces: {
          'eip155': RequiredNamespace(
            chains: ['eip155:${AppConfig.chainId}'],
            methods: ['eth_sendTransaction', 'personal_sign'],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
      );

      final Uri? uri = response.uri;
      if (uri != null) {
        // Open wallet app
        if (kIsWeb) {
          // For web, show QR code or deep link
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          // For mobile, try known wallet deep links first, then fallback to the raw WalletConnect URI.
          final encoded = Uri.encodeComponent(uri.toString());
          final candidates = <Uri>[
            Uri.parse('metamask://wc?uri=$encoded'),
            Uri.parse('trust://wc?uri=$encoded'),
            uri,
          ];

          bool launched = false;
          for (final candidate in candidates) {
            try {
              final ok = await launchUrl(candidate,
                  mode: LaunchMode.externalApplication);
              if (ok) {
                launched = true;
                break;
              }
            } catch (_) {}
          }

          if (!launched) {
            throw Exception(
                'No compatible wallet app found. Install MetaMask/Trust Wallet and try again.');
          }
        }
      }

      _session =
          await response.session.future.timeout(const Duration(minutes: 2));

      if (_session != null) {
        final accounts = _session!.namespaces['eip155']?.accounts ?? [];
        if (accounts.isNotEmpty) {
          _currentAddress = accounts.first.split(':').last;
          _connectionController.add(true);
          return _currentAddress;
        }
      }

      return null;
    } on TimeoutException {
      _lastError =
          'WalletConnect approval timed out. Please open your wallet app and approve the connection, then try again.';
      debugPrint('WalletConnect error: $_lastError');
      return null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('WalletConnect error: $e');
      return null;
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
    _lastError = null;
    _connectionController.add(false);
  }

  void _onSessionConnect(SessionConnect? event) {
    if (event != null) {
      _session = event.session;
      final accounts = _session!.namespaces['eip155']?.accounts ?? [];
      if (accounts.isNotEmpty) {
        _currentAddress = accounts.first.split(':').last;
        _connectionController.add(true);
      }
    }
  }

  void _onSessionDelete(SessionDelete? event) {
    _session = null;
    _currentAddress = null;
    _connectionController.add(false);
  }

  Future<String?> signMessage(String message) async {
    if (_session == null || _appKit == null || _currentAddress == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final signature = await _appKit!.request(
        topic: _session!.topic,
        chainId: 'eip155:${AppConfig.chainId}',
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
    if (_session == null || _appKit == null || _currentAddress == null) {
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
      final result = await _appKit!.request(
        topic: _session!.topic,
        chainId: 'eip155:${AppConfig.chainId}',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [tx],
        ),
      );
      return result as String?;
    } catch (e) {
      debugPrint('Send transaction error: $e');
      return null;
    }
  }

  void dispose() {
    _appKit?.onSessionConnect.unsubscribe(_onSessionConnect);
    _appKit?.onSessionDelete.unsubscribe(_onSessionDelete);
    _connectionController.close();
  }
}
