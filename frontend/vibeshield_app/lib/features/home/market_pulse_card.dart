import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/market_prices_provider.dart';

class MarketPulseCard extends ConsumerWidget {
  MarketPulseCard({super.key});

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
