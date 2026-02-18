import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/vibe_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/tx_history_provider.dart';
import '../../providers/insights_provider.dart' as insights;
import '../../core/config.dart';
import '../../core/agent_demo.dart';
import '../dashboard/vibe_meter_widget.dart';
import '../dashboard/sentiment_insights_widget.dart';
import '../dashboard/multi_token_dashboard_widget.dart';
import 'agent_profile_dialog.dart';
import 'market_pulse_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _tightAgentAvatarAssetPath = 'assets/tight_agent.png';
  static const String _looseAgentAvatarAssetPath = 'assets/loose_agent.png';

  String _agentAvatarPathForStrategy(int strategy) {
    return strategy == 2 ? _looseAgentAvatarAssetPath : _tightAgentAvatarAssetPath;
  }

  final _tokenController = TextEditingController(text: 'BTC');
  final _tokenIdController = TextEditingController(text: 'bitcoin');
  final _tokenAddressController = TextEditingController(text: '');
  final _amountController = TextEditingController(text: '1');
  final _tokenIdFocusNode = FocusNode();
  final _tokenAddressFocusNode = FocusNode();
  StreamSubscription<Uri>? _wcUriSub;
  bool _wcDialogOpen = false;

  bool _isSwapping = false;
  bool _agentBusy = false;
  String? _agentBusyAction; // spawn|approve|inject|topup
  int _selectedStrategy = 1; // 1 = TIGHT, 2 = LOOSE
  Future<AgentDemoConfig?>? _agentConfigFuture;
  Future<AgentDemoStatus?>? _agentStatusFuture;
  Future<AgentDemoContext?>? _agentDemoContextFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(insights.multiTokenProvider.notifier).fetchAll();
    });

    if (kIsWeb) {
      final walletService = ref.read(walletServiceProvider);
      _wcUriSub = walletService.wcUriStream.listen(_showWalletConnectQr);
    }
  }

  String _explorerTxUrl(String txHash, {int? chainId}) {
    final clean = txHash.trim();
    if (clean.isEmpty) return '';

    final cid = chainId ?? AppConfig.chainId;
    if (cid == 97) return 'https://testnet.bscscan.com/tx/$clean';
    if (cid == 56) return 'https://bscscan.com/tx/$clean';
    final base = AppConfig.explorerTxBaseUrl;
    return base.isNotEmpty ? '$base$clean' : '';
  }

  Future<void> _openExternalUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;

    final uri = Uri.tryParse(u);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid explorer URL')),
      );
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: $u')),
      );
    }
  }

  Future<void> _openExplorerTx(String txHash, {int? chainId}) async {
    final url = _explorerTxUrl(txHash, chainId: chainId);
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Explorer URL not available')),
      );
      return;
    }

    await _openExternalUrl(url);
  }

  // Helper methods for avatar and strategy-specific names
  String _getAgentName(int strategy, bool step2Done, bool step1Done) {
    if (strategy == 2) {
      // Loose strategy
      return step2Done
          ? 'Ranger of the Vibe'
          : step1Done
              ? 'Wandering Sentinel'
              : 'The Awakening Ranger';
    } else {
      // Tight strategy
      return step2Done
          ? 'The Iron Guardian'
          : step1Done
              ? 'Keeper of the Vault'
              : 'The Dormant Sentinel';
    }
  }

  String _getFlavorText(int strategy, bool step2Done, bool step1Done) {
    if (strategy == 2) {
      // Loose strategy
      return step2Done
          ? 'An adventurous spirit patrolling the volatile forests of BSC. Reacts to medium-risk indicators with precision strikes.'
          : step1Done
              ? 'Stirring to life... will soon begin its watchful patrol.'
              : 'Waiting to be awakened. Once active, will dance with market volatility.';
    } else {
      // Tight strategy
      return step2Done
          ? 'A vigilant protector monitoring the vault with iron discipline. Strikes only when danger is imminent and certain.'
          : step1Done
              ? 'Stirring to life... preparing for unwavering protection.'
              : 'Locked away, waiting for activation. Will guard your assets with absolute conviction.';
    }
  }

  String _getStrategyLabel(int strategy) {
    return strategy == 2 ? 'Loose' : 'Tight';
  }

  Color _getBorderColorForStrategy(int strategy, ColorScheme scheme) {
    return strategy == 2
        ? const Color(0xFFD4AF37) // Gold for Loose
        : const Color(0xFFC0C0C0); // Silver for Tight
  }

  void _showAgentProfileDialog({
    required String userAddress,
    required int strategy,
    required bool step1Done,
    required bool step2Done,
    required bool simulationActive,
    required String userWbnb,
    required String backendWbnb,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final agentName = _getAgentName(strategy, step2Done, step1Done);
    final flavorText = _getFlavorText(strategy, step2Done, step1Done);
    final strategyLabel = _getStrategyLabel(strategy);
    final borderColor = _getBorderColorForStrategy(strategy, scheme);
    final avatarPath = _agentAvatarPathForStrategy(strategy);

    // Status indicators
    final String statusIndicator =
        step2Done ? 'ðŸŸ¢ ONLINE' : 'ðŸŸ¡ DORMANT';
    final String protectionStatus =
        step2Done ? 'ðŸ›¡ï¸ PROTECTED' : 'â³ PENDING';
    final String gasTank =
        'â›½ ${userWbnb.isEmpty ? '0' : userWbnb} BNB';

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AgentProfileDialog(
          scheme: scheme,
          textTheme: textTheme,
          agentName: agentName,
          flavorText: flavorText,
          strategyLabel: strategyLabel,
          borderColor: borderColor,
          avatarPath: avatarPath,
          statusIndicator: statusIndicator,
          protectionStatus: protectionStatus,
          gasTank: gasTank,
          step1Done: step1Done,
          step2Done: step2Done,
          userAddress: userAddress,
          userWbnb: userWbnb,
        );
      },
    );
  }

  void _showWalletConnectQr(Uri uri) {
    if (!mounted || _wcDialogOpen) return;
    _wcDialogOpen = true;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final wcUrl = Uri.parse(
          'https://walletconnect.com/wc?uri=${Uri.encodeComponent(uri.toString())}',
        );

        return AlertDialog(
          title: const Text('Connect Wallet'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: uri.toString(),
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 12),
              SelectableText(
                uri.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await launchUrl(wcUrl, mode: LaunchMode.externalApplication);
              },
              child: const Text('Open WalletConnect'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      _wcDialogOpen = false;
    });
  }

  Future<void> _connectWallet() async {
    if (!mounted) return;

    final notifier = ref.read(walletProvider.notifier);

    if (!kIsWeb) {
      await notifier.connect();
      return;
    }

    final walletService = ref.read(walletServiceProvider);
    final hasInjected = walletService.hasInjected;

    await showDialog<void>(
      context: context,
      builder: (context) {
        Future<void> runConnect(Future<void> Function() action) async {
          await action();
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }

        return AlertDialog(
          title: const Text('Connect wallet'),
          content: Text(
            hasInjected
                ? 'Choose how to connect your wallet.'
                : 'MetaMask not detected. Use WalletConnect or install MetaMask.',
          ),
          actions: [
            if (hasInjected)
              TextButton(
                onPressed: () => runConnect(notifier.connectInjected),
                child: const Text('MetaMask'),
              ),
            TextButton(
              onPressed: () => runConnect(notifier.connectWalletConnect),
              child: const Text('WalletConnect'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    final err = ref.read(walletProvider).error;
    if (err != null && err.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static const List<Map<String, String>> _coinGeckoPresets = [
    {'symbol': 'BTC', 'id': 'bitcoin'},
    {'symbol': 'BNB', 'id': 'binancecoin'},
    {'symbol': 'ETH', 'id': 'ethereum'},
    {'symbol': 'USDT', 'id': 'tether'},
    {'symbol': 'SUI', 'id': 'sui'},
    {'symbol': 'SOL', 'id': 'solana'},
    {'symbol': 'XRP', 'id': 'ripple'},
    {'symbol': 'DOGE', 'id': 'dogecoin'},
  ];

  Iterable<String> _coinGeckoIdSuggestionsFor(
      {required String query, required String symbol}) {
    final q = query.trim().toLowerCase();
    final s = symbol.trim().toUpperCase();

    if (q.isEmpty) {
      final bySymbol = _coinGeckoPresets
          .where((e) => e['symbol'] == s)
          .map((e) => e['id']!)
          .toList();
      if (bySymbol.isNotEmpty) return bySymbol;
      return _coinGeckoPresets.map((e) => e['id']!);
    }

    final out = <String>{};
    for (final item in _coinGeckoPresets) {
      final s = (item['symbol'] ?? '').toLowerCase();
      final id = (item['id'] ?? '').toLowerCase();
      if (s.contains(q) || id.contains(q)) {
        out.add(item['id']!);
      }
    }
    return out;
  }

  void _applyPreset({required String symbol, required String coinGeckoId}) {
    setState(() {
      _tokenController.text = symbol;
      _tokenIdController.text = coinGeckoId;
    });
  }

  Future<void> _openTokenSearchModal() async {
    final initialSymbol = _tokenController.text.trim().toUpperCase();
    final initialCoinId = _tokenIdController.text.trim().toLowerCase();

    final symbolController = TextEditingController(text: initialSymbol);
    final coinIdController = TextEditingController(text: initialCoinId);
    final coinIdFocusNode = FocusNode();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final currentSymbol = symbolController.text.trim().toUpperCase();

              void applyModalPreset(String symbol, String coinId) {
                setModalState(() {
                  symbolController.text = symbol;
                  coinIdController.text = coinId;
                });
              }

              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Search Token',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Use this for tokens outside the dashboard cards.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('BTC'),
                          selected: currentSymbol == 'BTC',
                          onSelected: (_) => applyModalPreset('BTC', 'bitcoin'),
                        ),
                        ChoiceChip(
                          label: const Text('BNB'),
                          selected: currentSymbol == 'BNB',
                          onSelected: (_) =>
                              applyModalPreset('BNB', 'binancecoin'),
                        ),
                        ChoiceChip(
                          label: const Text('ETH'),
                          selected: currentSymbol == 'ETH',
                          onSelected: (_) =>
                              applyModalPreset('ETH', 'ethereum'),
                        ),
                        ChoiceChip(
                          label: const Text('USDT'),
                          selected: currentSymbol == 'USDT',
                          onSelected: (_) => applyModalPreset('USDT', 'tether'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: symbolController,
                      decoration: const InputDecoration(
                        labelText: 'Token Symbol',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 12),
                    RawAutocomplete<String>(
                      textEditingController: coinIdController,
                      focusNode: coinIdFocusNode,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        return _coinGeckoIdSuggestionsFor(
                          query: textEditingValue.text,
                          symbol: symbolController.text,
                        );
                      },
                      displayStringForOption: (opt) => opt,
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'CoinGecko ID',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        final opts = options.toList(growable: false);
                        if (opts.isEmpty) return const SizedBox.shrink();

                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxHeight: 220, maxWidth: 520),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: opts.length,
                                itemBuilder: (context, index) {
                                  final id = opts[index];
                                  final preset = _coinGeckoPresets.firstWhere(
                                    (e) => e['id'] == id,
                                    orElse: () => const <String, String>{},
                                  );
                                  final symbol = preset['symbol'];

                                  return ListTile(
                                    dense: true,
                                    title: Text(id),
                                    subtitle:
                                        (symbol != null && symbol.isNotEmpty)
                                            ? Text(symbol)
                                            : null,
                                    onTap: () => onSelected(id),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final token =
                              symbolController.text.trim().toUpperCase();
                          final tokenId =
                              coinIdController.text.trim().toLowerCase();
                          if (token.isEmpty || tokenId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Token Symbol and CoinGecko ID are required.')),
                            );
                            return;
                          }

                          _applyPreset(symbol: token, coinGeckoId: tokenId);
                          ref
                              .read(vibeNotifierProvider.notifier)
                              .checkVibe(token, tokenId);
                          ref
                              .read(insights.insightsProvider.notifier)
                              .fetchInsights(token);
                          Navigator.of(context).pop();
                        },
                        child: const Text('Check Vibe'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      symbolController.dispose();
      coinIdController.dispose();
      coinIdFocusNode.dispose();
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _tokenIdController.dispose();
    _tokenAddressController.dispose();
    _amountController.dispose();
    _tokenIdFocusNode.dispose();
    _tokenAddressFocusNode.dispose();
    _wcUriSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vibeState = ref.watch(vibeNotifierProvider);
    final walletState = ref.watch(walletProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VibeShield AI'),
        centerTitle: false,
        actions: [
          if (walletState.isConnected)
            IconButton(
              tooltip: 'Disconnect wallet',
              onPressed: () => ref.read(walletProvider.notifier).disconnect(),
              icon: const Icon(Icons.logout),
            )
          else
            IconButton(
              tooltip: 'Connect wallet',
              onPressed: _connectWallet,
              icon: const Icon(Icons.account_balance_wallet),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              scheme.surfaceContainerHighest.withValues(alpha: 0.20),
              scheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  MarketPulseCard(),
              const SizedBox(height: 16),
              _buildMultiTokenDashboardCard(),
              const SizedBox(height: 16),
              if (!walletState.isConnected) ...[
                _buildPreConnectLandingCard(context),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (walletState.error != null) ...[
                        Text(
                          walletState.error!,
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (walletState.isConnected) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Wallet: ${_short(walletState.address ?? '')}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Selected: ${_tokenController.text.trim().toUpperCase()}  (${_tokenIdController.text.trim().toLowerCase()})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _openTokenSearchModal,
                            child: const Text('Search token'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: vibeState.isLoading
                            ? null
                            : () {
                                final token =
                                    _tokenController.text.trim().toUpperCase();
                                final tokenId = _tokenIdController.text
                                    .trim()
                                    .toLowerCase();

                                // Fetch both vibe check and insights
                                ref
                                    .read(vibeNotifierProvider.notifier)
                                    .checkVibe(token, tokenId);
                                ref
                                    .read(insights.insightsProvider.notifier)
                                    .fetchInsights(token);
                              },
                        child: vibeState.isLoading
                            ? const _ScanningButtonLabel()
                            : const Text('Check Vibe'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (vibeState.error != null)
                Card(
                  color: Colors.red.shade900,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(vibeState.error!),
                  ),
                ),
              if (vibeState.isLoading) ...[
                const ScanningVibeMeterWidget(),
              ] else if (vibeState.result != null) ...[
                VibeMeterWidget(result: vibeState.result!),
                const SizedBox(height: 16),
                _buildAnalysisCard(vibeState.result!),
                const SizedBox(height: 16),
                _buildSentimentInsightsCard(),
              ],
              if (walletState.isConnected &&
                  (walletState.address?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 24),
                _buildAgentDemoCard(context, walletState.address!),
                const SizedBox(height: 16),
                _buildEmergencySwapCard(context, walletState.address!),
                const SizedBox(height: 16),
                _buildTxHistoryCard(context, walletState.address!),
              ]
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildPreConnectLandingCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    Widget feature(IconData icon, String label) {
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      );
    }

    Widget stepPill({required int n, required String label}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: scheme.primary.withValues(alpha: 0.35)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$n',
                  style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800, color: scheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.08),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: scheme.error.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'SYSTEM OFFLINE',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: scheme.error,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Icon(
                Icons.shield_outlined,
                size: 56,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 22),
              Text(
                "Don't let the crash\nwake you up.",
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                'AI Agent 24/7 protection against market dumps.',
                textAlign: TextAlign.center,
                style: textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  feature(Icons.shield_outlined, 'Non-custodial'),
                  feature(Icons.bolt_outlined, 'Fast response'),
                  feature(Icons.psychology_outlined, 'AI powered'),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  stepPill(n: 1, label: 'Connect'),
                  const SizedBox(width: 10),
                  stepPill(n: 2, label: 'Spawn agent'),
                  const SizedBox(width: 10),
                  stepPill(n: 3, label: 'Approve WBNB'),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _connectWallet,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.account_balance_wallet),
                      SizedBox(width: 10),
                      Text('CONNECT WALLET TO ACTIVATE'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'You can explore sentiment above without connecting.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgentDemoCard(BuildContext context, String userAddress) {
    final api = ref.read(insights.apiServiceProvider);
    final walletService = ref.read(walletServiceProvider);

    void retryLoadConfig() {
      setState(() {
        _agentConfigFuture = api.getAgentDemoConfig();
      });
    }

    void refreshAgentStatus() {
      setState(() {
        _agentStatusFuture = api.getAgentDemoStatus(userAddress: userAddress);
        _agentDemoContextFuture = api.getDemoContext();
      });
    }

    String formatWeiToBnb(BigInt? wei) {
      if (wei == null) return '';

      const decimals = 18;
      final s = wei.toString();
      if (s == '0') return '0';
      final padded = s.padLeft(decimals + 1, '0');
      final intPart = padded.substring(0, padded.length - decimals);
      var frac = padded.substring(padded.length - decimals);
      // Keep up to 6 decimals for readability.
      frac = frac.substring(0, 6);
      frac = frac.replaceFirst(RegExp(r'0+$'), '');
      return frac.isEmpty ? intPart : '$intPart.$frac';
    }

    Future<T?> runWithBlockingDialog<T>({
      required String title,
      required String message,
      required Future<T?> Function() action,
      bool showOpenWallet = false,
    }) async {
      if (!mounted) return null;

      // Show dialog first.
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ),
            actions: [
              if (showOpenWallet)
                TextButton(
                  onPressed: () => walletService.openWalletApp(),
                  child: const Text('Open wallet'),
                ),
            ],
          );
        },
      );

      // Optionally try to bring wallet to foreground.
      if (showOpenWallet) {
        unawaited(walletService.openWalletApp());
      }

      try {
        return await action();
      } finally {
        if (mounted) {
          try {
            Navigator.of(context, rootNavigator: true).pop();
          } catch (_) {
            // ignore
          }
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Agent', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<AgentDemoConfig?>(
              future: _agentConfigFuture ??= api.getAgentDemoConfig(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Text('Loading on-chain config...');
                }

                if (snapshot.hasError) {
                  final msg = snapshot.error.toString();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Failed to load on-chain config.'),
                      const SizedBox(height: 6),
                      Text(
                        msg,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _agentBusy ? null : retryLoadConfig,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  );
                }

                final cfg = snapshot.data;
                if (cfg == null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No config returned from backend.'),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _agentBusy ? null : retryLoadConfig,
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  );
                }

                final feeWei = cfg.creationFeeWei;
                final feeBnb = formatWeiToBnb(feeWei);
                final configError = cfg.configError;

                return FutureBuilder<AgentDemoStatus?>(
                  future: _agentStatusFuture ??=
                      api.getAgentDemoStatus(userAddress: userAddress),
                  builder: (context, statusSnap) {
                    final status = statusSnap.data;
                    final step1Done = status?.isAgentActive == true;
                    final step2Done = status?.hasApproval == true;
                    final userWbnbBnb = formatWeiToBnb(status?.userWbnbWei);
                    final backendWbnbBnb =
                        formatWeiToBnb(status?.backendWbnbWei);
                    final canExecuteByBalance =
                        status == null || status.userWbnbWei > BigInt.zero;
                    final isReady = step1Done && step2Done;

                    return FutureBuilder<AgentDemoContext?>(
                      future: _agentDemoContextFuture ??= api.getDemoContext(),
                      builder: (context, injectedSnap) {
                        final injected = injectedSnap.data;
                        final simulationActive = injected?.isActive == true;

                        Future<void> topUpDemoWbnb() async {
                          setState(() {
                            _agentBusy = true;
                            _agentBusyAction = 'topup';
                          });
                          try {
                            final topup = await runWithBlockingDialog<
                                AgentDemoTopUpResult>(
                              title: 'Funding demo WBNB',
                              message:
                                  'Requesting demo WBNB top-up to your wallet. Please waitâ€¦',
                              action: () => api.topUpAgentDemoWbnb(
                                userAddress: userAddress,
                              ),
                            );

                            if (!mounted || topup == null) return;
                            if (!topup.success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    topup.error ??
                                        'Failed to top up demo WBNB.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final amount = formatWeiToBnb(topup.amountWei);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Demo top-up sent: ${amount.isEmpty ? 'WBNB funded' : '$amount WBNB funded'}',
                                ),
                              ),
                            );
                            refreshAgentStatus();
                          } finally {
                            if (mounted) {
                              setState(() {
                                _agentBusy = false;
                                _agentBusyAction = null;
                              });
                            }
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _showAgentProfileDialog(
                                  userAddress: userAddress,
                                  strategy: (status?.strategy ?? _selectedStrategy) == 2 ? 2 : 1,
                                  step1Done: step1Done,
                                  step2Done: step2Done,
                                  simulationActive: simulationActive,
                                  userWbnb: userWbnbBnb,
                                  backendWbnb: backendWbnbBnb,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Top row: title and chevron indicator
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (simulationActive) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .errorContainer
                                                          .withValues(alpha: 0.35),
                                                      borderRadius:
                                                          BorderRadius.circular(999),
                                                    ),
                                                    child: Text(
                                                      'âš ï¸ SIMULATION MODE',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight.w700),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                                Text(
                                                  isReady
                                                      ? 'ðŸŸ¢ Agent Active'
                                                      : 'âš ï¸ Agent Setup Required',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                          fontWeight: FontWeight.w700),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Chevron indicator on the right
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Icon(
                                              Icons.chevron_right,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              size: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        isReady
                                            ? 'Guardian is monitoring your wallet 24/7. Use simulation injection to test black-swan response.'
                                            : 'Complete setup in 2 steps: Activate agent and approve WBNB.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Click to view agent identity.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      if (simulationActive &&
                                          injected != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          'Injected: ${injected.headline}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (configError != null &&
                                configError.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Config error: $configError',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (feeWei == null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Unable to fetch creation fee. Backend may not have RPC access to BSC Testnet.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'Network: BSC Testnet${feeBnb.isEmpty ? '' : ' â€¢ Activation fee: $feeBnb BNB'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (statusSnap.connectionState ==
                                ConnectionState.waiting) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Checking on-chain step status...',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ] else if (status != null) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    step1Done
                                        ? 'âœ… Agent active'
                                        : 'â³ Agent pending',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  Text(
                                    step2Done
                                        ? 'âœ… WBNB approved'
                                        : 'â³ Approval pending',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your WBNB: ${userWbnbBnb.isEmpty ? '0' : userWbnbBnb} | Demo faucet: ${backendWbnbBnb.isEmpty ? '0' : backendWbnbBnb}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _agentBusy ? null : topUpDemoWbnb,
                                  icon: (_agentBusy &&
                                          _agentBusyAction == 'topup')
                                      ? const SizedBox(
                                          height: 14,
                                          width: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.water_drop_outlined),
                                  label: const Text('ðŸ’§ Top-up WBNB'),
                                ),
                              ),
                              if (!canExecuteByBalance) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Need testnet funds? Tap Top-up WBNB.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              if (status.statusError != null &&
                                  status.statusError!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Status warning: ${status.statusError}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                            const SizedBox(height: 12),
                            if (!step1Done) ...[
                              const Text(
                                  'Step 1 â€” Choose strategy and activate agent'),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Strategy:'),
                                  const SizedBox(width: 12),
                                  DropdownButton<int>(
                                    value: _selectedStrategy,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 1, child: Text('ðŸ›¡ï¸ Tight')),
                                      DropdownMenuItem(
                                          value: 2, child: Text('ðŸ’Ž Loose')),
                                    ],
                                    onChanged: _agentBusy
                                        ? null
                                        : (v) {
                                            if (v == null) return;
                                            setState(
                                                () => _selectedStrategy = v);
                                          },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _agentBusy
                                      ? null
                                      : () async {
                                          final requiredChainId =
                                              cfg.chainId ?? AppConfig.chainId;
                                          final connectedChainId =
                                              walletService.chainId ??
                                                  AppConfig.chainId;
                                          if (connectedChainId !=
                                              requiredChainId) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Switch wallet network to chainId $requiredChainId (BSC Testnet) then try again.',
                                                ),
                                                action: SnackBarAction(
                                                  label: 'Open wallet',
                                                  onPressed: () => walletService
                                                      .openWalletApp(),
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          if (feeWei == null) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Cannot spawn: activation fee is unknown.',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          setState(() {
                                            _agentBusy = true;
                                            _agentBusyAction = 'spawn';
                                          });
                                          try {
                                            final data = AgentDemoTxBuilder
                                                .spawnAgentData(
                                              strategy: _selectedStrategy,
                                            );

                                            final txHash =
                                                await runWithBlockingDialog<
                                                    String?>(
                                              title: 'Confirm in wallet',
                                              message:
                                                  'Please approve agent activation transaction in wallet.',
                                              showOpenWallet: true,
                                              action: () =>
                                                  walletService.sendTransaction(
                                                to: cfg.registry,
                                                data: data,
                                                valueWei: feeWei,
                                              ),
                                            );

                                            if (!mounted) return;
                                            if (txHash == null ||
                                                txHash.isEmpty) {
                                              final err =
                                                  walletService.lastError ??
                                                      'No wallet error detail';
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Spawn not confirmed. ($err)'),
                                                ),
                                              );
                                              return;
                                            }

                                            final url = _explorerTxUrl(
                                              txHash,
                                              chainId: cfg.chainId,
                                            );
                                            await api.logAgentWalletTx(
                                              userAddress: userAddress,
                                              txHash: txHash,
                                              tokenAddress: cfg.registry,
                                              kind: 'spawn',
                                            );
                                            ref.invalidate(
                                                txHistoryProvider(userAddress));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Agent activated. Tx: $txHash'),
                                                action: url.isEmpty
                                                    ? null
                                                    : SnackBarAction(
                                                        label: 'View',
                                                        onPressed: () =>
                                                            _openExternalUrl(
                                                                url),
                                                      ),
                                              ),
                                            );
                                            refreshAgentStatus();
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _agentBusy = false;
                                                _agentBusyAction = null;
                                              });
                                            }
                                          }
                                        },
                                  child: (_agentBusy &&
                                          _agentBusyAction == 'spawn')
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('ðŸ›¡ï¸ Activate VibeShield'),
                                ),
                              ),
                            ],
                            if (step1Done && !step2Done) ...[
                              const Text('Step 2 â€” Grant WBNB permission'),
                              const SizedBox(height: 8),
                              Text(
                                'Approve WBNB so the agent can protect your funds when triggered.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Text('Strategy:'),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedStrategy == 1 ? 'Tight' : 'Loose',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                            if (step1Done && !step2Done)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _agentBusy
                                      ? null
                                      : () async {
                                          final requiredChainId =
                                              cfg.chainId ?? AppConfig.chainId;
                                          final connectedChainId =
                                              walletService.chainId ??
                                                  AppConfig.chainId;
                                          if (connectedChainId !=
                                              requiredChainId) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Switch wallet network to chainId $requiredChainId (BSC Testnet) then try again.',
                                                ),
                                                action: SnackBarAction(
                                                  label: 'Open wallet',
                                                  onPressed: () => walletService
                                                      .openWalletApp(),
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          setState(() {
                                            _agentBusy = true;
                                            _agentBusyAction = 'approve';
                                          });
                                          try {
                                            debugPrint(
                                              '[agent] approve start chain=${cfg.chainId ?? AppConfig.chainId} wbnb=${cfg.wbnb} router=${cfg.router}',
                                            );
                                            final data =
                                                AgentDemoTxBuilder.approveData(
                                              spender: cfg.router,
                                              amount: AgentDemoTxBuilder
                                                  .maxUint256(),
                                            );

                                            final txHash =
                                                await runWithBlockingDialog<
                                                    String?>(
                                              title: 'Confirm in wallet',
                                              message:
                                                  'Please confirm the Approve transaction in your wallet. This allows the router to spend your WBNB.',
                                              showOpenWallet: true,
                                              action: () =>
                                                  walletService.sendTransaction(
                                                to: cfg.wbnb,
                                                data: data,
                                              ),
                                            );

                                            if (!mounted) return;
                                            if (txHash == null ||
                                                txHash.isEmpty) {
                                              final err =
                                                  walletService.lastError ??
                                                      'No wallet error detail';
                                              debugPrint(
                                                  '[agent] approve failed: $err');
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Approve was not confirmed in wallet. ($err)',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            debugPrint(
                                                '[agent] approve txHash=$txHash');

                                            final url = _explorerTxUrl(
                                              txHash,
                                              chainId: cfg.chainId,
                                            );
                                            await api.logAgentWalletTx(
                                              userAddress: userAddress,
                                              txHash: txHash,
                                              tokenAddress: cfg.wbnb,
                                              kind: 'approve',
                                            );
                                            ref.invalidate(
                                                txHistoryProvider(userAddress));
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Approve submitted: $txHash. Waiting confirmation on chain...'),
                                                action: url.isEmpty
                                                    ? null
                                                    : SnackBarAction(
                                                        label: 'View',
                                                        onPressed: () =>
                                                            _openExternalUrl(
                                                                url),
                                                      ),
                                              ),
                                            );
                                            refreshAgentStatus();
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _agentBusy = false;
                                                _agentBusyAction = null;
                                              });
                                            }
                                          }
                                        },
                                  child: (_agentBusy &&
                                          _agentBusyAction == 'approve')
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('âœ… Approve WBNB'),
                                ),
                              ),
                            if (isReady) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.20),
                                ),
                                child: Text(
                                  'Demo Zone: Hybrid Trigger\nInject synthetic black-swan news. Monitor loop + AI decide execution automatically.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonal(
                                  onPressed: (_agentBusy ||
                                          !canExecuteByBalance)
                                      ? null
                                      : () async {
                                          setState(() {
                                            _agentBusy = true;
                                            _agentBusyAction = 'inject';
                                          });
                                          try {
                                            final result =
                                                await runWithBlockingDialog<
                                                    AgentDemoInjectResult>(
                                              title:
                                                  'Injecting simulation context',
                                              message:
                                                  'Sending black-swan context to backend. Monitor loop and AI will react automaticallyâ€¦',
                                              action: () =>
                                                  api.injectDemoContext(
                                                token: 'BNB',
                                                type: 'BRIDGE_HACK',
                                                severity: 'CRITICAL',
                                              ),
                                            );

                                            if (!mounted || result == null)
                                              return;
                                            if (!result.ok) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(result.error ??
                                                      'Failed to inject simulation context.'),
                                                ),
                                              );
                                              return;
                                            }

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'News injected. Watch the AI monitor react on next cycle.'),
                                              ),
                                            );

                                            refreshAgentStatus();
                                            ref.invalidate(
                                                txHistoryProvider(userAddress));
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Injection failed: $e'),
                                              ),
                                            );
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _agentBusy = false;
                                                _agentBusyAction = null;
                                              });
                                            }
                                          }
                                        },
                                  child: (_agentBusy &&
                                          _agentBusyAction == 'inject')
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'ðŸ’‰ Inject Black Swan Event'),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencySwapCard(BuildContext context, String userAddress) {
    final api = ref.read(insights.apiServiceProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String chainLabelFor(int? chainId) {
      if (chainId == 1) return 'Ethereum';
      if (chainId == 56) return 'BSC';
      if (chainId == 97) return 'BSC Testnet';
      return chainId == null ? '' : 'Chain $chainId';
    }

    List<Map<String, dynamic>> filterPresetOptions(
      List<Map<String, dynamic>> items,
      String query,
    ) {
      final q = query.trim().toLowerCase();
      if (items.isEmpty) return const <Map<String, dynamic>>[];

      bool matchesQuery(Map<String, dynamic> it) {
        final address = (it['address'] ?? '').toString().trim().toLowerCase();
        final symbol = (it['symbol'] ?? '').toString().trim().toLowerCase();
        final name = (it['name'] ?? '').toString().trim().toLowerCase();
        final chainId =
            it['chainId'] is num ? (it['chainId'] as num).toInt() : null;
        final chainLabel = chainLabelFor(chainId).toLowerCase();

        if (q.isEmpty) return true;
        if (q.startsWith('0x')) return address.startsWith(q);
        if (q.contains('bsc')) {
          return chainId == 56 || chainLabel.contains('bsc');
        }
        if (q.contains('test')) {
          return chainId == 97 || chainLabel.contains('test');
        }

        return symbol.contains(q) ||
            name.contains(q) ||
            address.contains(q) ||
            chainLabel.contains(q);
      }

      const maxOptions = 10;
      final results = <Map<String, dynamic>>[];
      for (final it in items) {
        if (matchesQuery(it)) {
          results.add(it);
          if (results.length >= maxOptions) break;
        }
      }
      return results;
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(
          Icons.swap_horiz_rounded,
          color: scheme.onSurfaceVariant,
          size: 22,
        ),
        title: Text(
          'Emergency Swap',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Manual guardian swap execution',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        initiallyExpanded: false,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: () async {
              final filtered =
                  await api.getTokenPresets(chainId: AppConfig.chainId);
              if (filtered.isNotEmpty) return filtered;
              return api.getTokenPresets();
            }(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              String? current;
              final currentAddress = _tokenAddressController.text.trim();
              for (final it in items) {
                final addr = (it['address'] ?? '').toString().trim();
                if (addr.isNotEmpty &&
                    addr.toLowerCase() == currentAddress.toLowerCase()) {
                  current = addr;
                  break;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (items.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: current,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Token Preset',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        labelStyle: textTheme.bodySmall,
                      ),
                      items: items.map((it) {
                        final symbol = (it['symbol'] ?? '').toString().trim();
                        final name = (it['name'] ?? symbol).toString().trim();
                        final addr = (it['address'] ?? '').toString().trim();
                        final chainId = it['chainId'] is num
                            ? (it['chainId'] as num).toInt()
                            : null;
                        final chainLabel = chainLabelFor(chainId);

                        final title =
                            symbol.isNotEmpty ? '$symbol â€” $name' : name;
                        final subtitle =
                            chainLabel.isNotEmpty ? '($chainLabel)' : '';

                        return DropdownMenuItem<String>(
                          value: addr,
                          child: Text(
                            subtitle.isNotEmpty ? '$title $subtitle' : title,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        );
                      }).toList(growable: false),
                      onChanged: (addr) {
                        if (addr == null || addr.trim().isEmpty) return;
                        setState(() {
                          _tokenAddressController.text = addr.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  RawAutocomplete<Map<String, dynamic>>(
                    textEditingController: _tokenAddressController,
                    focusNode: _tokenAddressFocusNode,
                    displayStringForOption: (option) =>
                        (option['address'] ?? '').toString().trim(),
                    optionsBuilder: (textEditingValue) =>
                        filterPresetOptions(items, textEditingValue.text),
                    onSelected: (option) {
                      final addr =
                          (option['address'] ?? '').toString().trim();
                      if (addr.isEmpty) return;
                      setState(() {
                        _tokenAddressController.text = addr;
                      });
                    },
                    fieldViewBuilder: (context, textEditingController,
                        focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        style: textTheme.bodySmall,
                        decoration: InputDecoration(
                          labelText: 'Token Address (ERC20)',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          labelStyle: textTheme.bodySmall,
                          helperText:
                              'Type 0xâ€¦ or search by name/symbol',
                          helperStyle: textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxHeight: 200, maxWidth: 480),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final it = options.elementAt(index);
                                final symbol =
                                    (it['symbol'] ?? '').toString().trim();
                                final name =
                                    (it['name'] ?? symbol).toString().trim();
                                final addr =
                                    (it['address'] ?? '').toString().trim();
                                final chainId = it['chainId'] is num
                                    ? (it['chainId'] as num).toInt()
                                    : null;
                                final chainLabel = chainLabelFor(chainId);

                                final title = symbol.isNotEmpty
                                    ? '$symbol â€” $name'
                                    : name;
                                final subtitleParts = <String>[];
                                if (chainLabel.isNotEmpty) {
                                  subtitleParts.add(chainLabel);
                                }
                                if (addr.isNotEmpty) subtitleParts.add(addr);

                                return ListTile(
                                  dense: true,
                                  title: Text(title,
                                      style: textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: subtitleParts.isEmpty
                                      ? null
                                      : Text(
                                          subtitleParts.join(' â€¢ '),
                                          style: textTheme.bodySmall?.copyWith(
                                            fontSize: 10,
                                            color: scheme.onSurfaceVariant,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                  onTap: () => onSelected(it),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amountController,
            style: textTheme.bodySmall,
            decoration: InputDecoration(
              labelText: 'Amount (human readable)',
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              labelStyle: textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.errorContainer,
                foregroundColor: scheme.onErrorContainer,
                textStyle:
                    textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              onPressed: _isSwapping
                  ? null
                  : () async {
                      final tokenAddress =
                          _tokenAddressController.text.trim();
                      final amount = _amountController.text.trim();

                      if (tokenAddress.isEmpty || amount.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Token address and amount are required.')),
                        );
                        return;
                      }

                      setState(() => _isSwapping = true);
                      try {
                        final result = await api.executeSwap(
                          userAddress: userAddress,
                          tokenAddress: tokenAddress,
                          amount: amount,
                        );

                        if (!context.mounted) return;

                        final txHash = result['txHash'];
                        if (txHash != null &&
                            txHash is String &&
                            txHash.isNotEmpty) {
                          ref.invalidate(txHistoryProvider(userAddress));
                          final url = _explorerTxUrl(txHash);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Swap submitted: ${url.isNotEmpty ? url : txHash}'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Swap result: ${result.toString()}')),
                          );
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Swap failed: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => _isSwapping = false);
                      }
                    },
              icon: _isSwapping
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.flash_on, size: 18),
              label: Text(_isSwapping ? 'Executing...' : 'Execute Swap'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Guardian triggers vault swap on-chain. Requires prior approval and vault config.',
            style: textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxHistoryCard(BuildContext context, String userAddress) {
    final asyncItems = ref.watch(txHistoryProvider(userAddress));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'On-chain History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.invalidate(txHistoryProvider(userAddress)),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            asyncItems.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Text('No transactions recorded yet.');
                }

                return Column(
                  children: items
                      .take(10)
                      .map(
                        (t) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(_short(t.txHash)),
                          subtitle: Text(
                            '${DateTime.fromMillisecondsSinceEpoch(t.timestamp).toLocal()} â€¢ ${t.source}',
                          ),
                          trailing: TextButton(
                            onPressed: () => _openExplorerTx(t.txHash),
                            child: const Text('Explorer'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load history: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Analysis', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('Model: ${result.analysis.aiModel}'),
            Text('Risk Score: ${result.analysis.riskScore.toStringAsFixed(1)}'),
            Text(
                'Action: ${result.analysis.shouldExit ? "ðŸš¨ EXIT" : "âœ… HOLD"}'),
            const SizedBox(height: 8),
            Text(result.analysis.reason),
          ],
        ),
      ),
    );
  }

  // Multi-Token Dashboard Card
  Widget _buildMultiTokenDashboardCard() {
    final multiTokenState = ref.watch(insights.multiTokenProvider);

    return MultiTokenDashboardWidget(
      tokens: multiTokenState.tokens ?? {},
      source: multiTokenState.source,
      updatedAt: multiTokenState.updatedAt,
      stats: multiTokenState.stats,
      onTokenSelected: (token, coinGeckoId) {
        _applyPreset(symbol: token, coinGeckoId: coinGeckoId);
        ref.read(vibeNotifierProvider.notifier).checkVibe(
              token,
              coinGeckoId,
            );
        // Keep Insights in sync with card-tap checks.
        ref.read(insights.insightsProvider.notifier).fetchInsights(token);
      },
    );
  }

  Widget _buildSentimentInsightsCard() {
    final insightsState = ref.watch(insights.insightsProvider);

    if (insightsState.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (insightsState.data != null) {
      return SentimentInsightsWidget(insightsData: insightsState.data!);
    }

    return const SizedBox.shrink();
  }

  String _short(String s) {
    if (s.length <= 12) return s;
    return '${s.substring(0, 6)}...${s.substring(s.length - 4)}';
  }
}

class _ScanningButtonLabel extends StatelessWidget {
  const _ScanningButtonLabel();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Text('Scanning Social Signals...'),
      ],
    );
  }
}
