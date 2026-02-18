import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/insights_provider.dart' as insights;
import '../../services/api_service.dart';

/// Premium Market Intelligence card — only shown to users with active Agent.
/// Pulls real-time data from CoinGecko + Cryptoracle + Kalibr AI brief.
class MarketIntelCard extends ConsumerWidget {
  const MarketIntelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intelAsync = ref.watch(insights.marketIntelProvider);
    final scheme = Theme.of(context).colorScheme;

    return intelAsync.when(
      loading: () => _buildShell(context, scheme, isLoading: true),
      error: (_, __) => const SizedBox.shrink(),
      data: (intel) => _buildCard(context, scheme, intel, ref),
    );
  }

  Widget _buildShell(BuildContext context, ColorScheme scheme,
      {bool isLoading = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purpleAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_graph, color: Colors.purpleAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'AGENT INTEL FEED',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                ),
            ],
          ),
          if (isLoading) ...[
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Loading market intelligence...',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCard(
      BuildContext context, ColorScheme scheme, MarketIntel intel, WidgetRef ref) {
    final sentimentColor = intel.sentimentScore >= 65
        ? Colors.green
        : intel.sentimentScore <= 35
            ? Colors.red
            : Colors.amber;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purpleAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Header row ---
          Row(
            children: [
              const Icon(Icons.auto_graph, color: Colors.purpleAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'AGENT INTEL FEED',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
              ),
              const Spacer(),
              _SentimentBadge(
                score: intel.sentimentScore,
                label: intel.sentimentLabel,
                color: sentimentColor,
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => ref.invalidate(insights.marketIntelProvider),
                child: Icon(Icons.refresh, size: 16, color: Colors.grey[500]),
              ),
            ],
          ),

          const Divider(height: 20, color: Colors.white10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.20)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology, color: Colors.purpleAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    intel.aiBrief,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: _CoinTicker(symbol: 'BTC', coin: intel.btc)),
              Container(width: 1, height: 40, color: Colors.white10),
              Expanded(child: _CoinTicker(symbol: 'ETH', coin: intel.eth)),
              Container(width: 1, height: 40, color: Colors.white10),
              Expanded(child: _CoinTicker(symbol: 'BNB', coin: intel.bnb)),
            ],
          ),

          const SizedBox(height: 8),

          // --- Data source attribution ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified, size: 10, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'CoinGecko Pro · Cryptoracle · Kalibr AI',
                style: TextStyle(fontSize: 9, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _SentimentBadge extends StatelessWidget {
  final int score;
  final String label;
  final Color color;

  const _SentimentBadge({
    required this.score,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.40)),
      ),
      child: Text(
        '$label ($score)',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CoinTicker extends StatelessWidget {
  final String symbol;
  final CoinIntel? coin;

  const _CoinTicker({required this.symbol, required this.coin});

  @override
  Widget build(BuildContext context) {
    if (coin == null) {
      return Center(
        child: Text(symbol, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      );
    }

    final isUp = coin!.change24h >= 0;
    final changeColor = isUp ? Colors.greenAccent : Colors.redAccent;
    final arrow = isUp ? '▲' : '▼';

    // Format price: BTC uses comma thousands, others use decimal
    final priceStr = coin!.price >= 1000
        ? '\$${_formatCompact(coin!.price)}'
        : '\$${coin!.price.toStringAsFixed(2)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          symbol,
          style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          priceStr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(
          '$arrow ${coin!.change24h.abs().toStringAsFixed(2)}%',
          style: TextStyle(color: changeColor, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _formatCompact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(2);
  }
}
