import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/vibe_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/tx_history_provider.dart';
import '../../providers/market_prices_provider.dart';
import '../../providers/insights_provider.dart' as insights;
import '../../core/config.dart';
import '../dashboard/vibe_meter_widget.dart';
import '../dashboard/sentiment_insights_widget.dart';
import '../dashboard/multi_token_dashboard_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _tokenController = TextEditingController(text: 'BTC');
  final _tokenIdController = TextEditingController(text: 'bitcoin');
  final _tokenAddressController = TextEditingController(text: '');
  final _amountController = TextEditingController(text: '1');
  final _tokenIdFocusNode = FocusNode();
  final _tokenAddressFocusNode = FocusNode();

  bool _isSwapping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(insights.multiTokenProvider.notifier).fetchAll();
    });
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
              onPressed: () => ref.read(walletProvider.notifier).connect(),
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
          child: Column(
            children: [
              _MarketPulseCard(),
              const SizedBox(height: 16),
              _buildMultiTokenDashboardCard(),
              const SizedBox(height: 16),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              walletState.isConnected
                                  ? 'Wallet: ${_short(walletState.address ?? '')}'
                                  : 'Wallet: not connected',
                            ),
                          ),
                          if (!walletState.isConnected)
                            ElevatedButton(
                              onPressed: () =>
                                  ref.read(walletProvider.notifier).connect(),
                              child: const Text('Connect'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
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
                _buildEmergencySwapCard(context, walletState.address!),
                const SizedBox(height: 16),
                _buildTxHistoryCard(context, walletState.address!),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencySwapCard(BuildContext context, String userAddress) {
    final api = ref.read(insights.apiServiceProvider);

    String chainLabelFor(int? chainId) {
      if (chainId == 11155111) return 'Sepolia';
      if (chainId == 1) return 'Ethereum';
      if (chainId == 56) return 'BSC';
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
        if (q.contains('sepo')) {
          return chainId == 11155111 || chainLabel.contains('sepo');
        }
        if (q.contains('bsc')) {
          return chainId == 56 || chainLabel.contains('bsc');
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emergency Swap',
                style: Theme.of(context).textTheme.titleLarge),
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
                        decoration: const InputDecoration(
                          labelText: 'Token Preset',
                          border: OutlineInputBorder(),
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
                              symbol.isNotEmpty ? '$symbol — $name' : name;
                          final subtitle =
                              chainLabel.isNotEmpty ? '($chainLabel)' : '';

                          return DropdownMenuItem<String>(
                            value: addr,
                            child: Text(
                              subtitle.isNotEmpty ? '$title $subtitle' : title,
                              overflow: TextOverflow.ellipsis,
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
                      const SizedBox(height: 12),
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
                          decoration: const InputDecoration(
                            labelText: 'Token Address (ERC20)',
                            border: OutlineInputBorder(),
                            helperText:
                                'Type 0x… or search by name/symbol (e.g. sepo)',
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxHeight: 240, maxWidth: 520),
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
                                      ? '$symbol — $name'
                                      : name;
                                  final subtitleParts = <String>[];
                                  if (chainLabel.isNotEmpty) {
                                    subtitleParts.add(chainLabel);
                                  }
                                  if (addr.isNotEmpty) subtitleParts.add(addr);

                                  return ListTile(
                                    dense: true,
                                    title: Text(title,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: subtitleParts.isEmpty
                                        ? null
                                        : Text(
                                            subtitleParts.join(' • '),
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
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (human readable)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
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
                            final url = AppConfig.explorerTxBaseUrl.isNotEmpty
                                ? '${AppConfig.explorerTxBaseUrl}$txHash'
                                : txHash;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Swap submitted: $url')),
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
                child: _isSwapping
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Execute Emergency Swap (Guardian)'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: This triggers the backend guardian to call the vault. You still need on-chain approval + vault config on the user wallet.',
            ),
          ],
        ),
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
                            '${DateTime.fromMillisecondsSinceEpoch(t.timestamp).toLocal()} • ${t.source}',
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              final base = AppConfig.explorerTxBaseUrl;
                              final url = base.isNotEmpty
                                  ? '$base${t.txHash}'
                                  : t.txHash;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(url)),
                              );
                            },
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
                'Action: ${result.analysis.shouldExit ? "🚨 EXIT" : "✅ HOLD"}'),
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

class _MarketPulseCard extends ConsumerWidget {
  _MarketPulseCard();

  static const _order = <String>[
    'bitcoin',
    'binancecoin',
    'ethereum',
    'tether'
  ];

  static const _labels = <String, String>{
    'bitcoin': 'BTC',
    'binancecoin': 'BNB',
    'ethereum': 'ETH',
    'tether': 'USDT',
  };

  final _money = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
  final _compact = NumberFormat.compactCurrency(symbol: r'$', decimalDigits: 2);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pricesAsync = ref.watch(marketPricesProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market Pulse',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Realtime from CoinGecko',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 560;
                final cols = isNarrow ? 2 : 4;
                const spacing = 12.0;
                final tileWidth =
                    (constraints.maxWidth - (spacing * (cols - 1))) / cols;

                return pricesAsync.when(
                  data: (items) {
                    final byId = {for (final it in items) it.token: it};

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: _order.map((id) {
                        final label = _labels[id] ?? id.toUpperCase();
                        final data = byId[id];
                        return SizedBox(
                          width: tileWidth,
                          child: _MarketTile(
                            label: label,
                            price: data?.price,
                            change24h: data?.priceChange24h,
                            formatter: label == 'USDT' ? _money : _compact,
                          ),
                        );
                      }).toList(growable: false),
                    );
                  },
                  loading: () {
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: _order.map((id) {
                        final label = _labels[id] ?? id.toUpperCase();
                        return SizedBox(
                          width: tileWidth,
                          child: _MarketTile(
                            label: label,
                            price: null,
                            change24h: null,
                            formatter: _compact,
                            isLoading: true,
                          ),
                        );
                      }).toList(growable: false),
                    );
                  },
                  error: (_, __) {
                    return Text(
                      'Failed to load market prices.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.error),
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
}

class _MarketTile extends StatelessWidget {
  const _MarketTile({
    required this.label,
    required this.price,
    required this.change24h,
    required this.formatter,
    this.isLoading = false,
  });

  final String label;
  final double? price;
  final double? change24h;
  final NumberFormat formatter;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final change = change24h;
    final isUp = (change ?? 0) >= 0;
    final accent = change == null
        ? scheme.onSurfaceVariant
        : (isUp ? scheme.tertiary : scheme.error);

    final priceText =
        isLoading ? '—' : (price == null ? '—' : formatter.format(price));

    final changeText = isLoading
        ? '…'
        : (change == null ? '—' : '${change.toStringAsFixed(2)}%');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            priceText,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isLoading
                    ? Icons.sync
                    : (change == null
                        ? Icons.remove
                        : (isUp ? Icons.trending_up : Icons.trending_down)),
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                changeText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
