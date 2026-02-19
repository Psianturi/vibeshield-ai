import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MultiTokenDashboardWidget extends StatelessWidget {
  final Map<String, dynamic> tokens;
  final Function(String token, String coinGeckoId) onTokenSelected;
  final String? source;
  final int? updatedAt;
  final Map<String, dynamic>? stats;

  const MultiTokenDashboardWidget({
    super.key,
    required this.tokens,
    required this.onTokenSelected,
    this.source,
    this.updatedAt,
    this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isFallback = source == 'fallback';
    final updatedTime = updatedAt != null
        ? DateFormat('HH:mm:ss')
            .format(DateTime.fromMillisecondsSinceEpoch(updatedAt!))
        : null;

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
                    '📊 Multi-Token Sentiment',
                    style: theme.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Source indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isFallback
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFallback ? Colors.orange : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFallback ? Icons.warning_amber : Icons.check_circle,
                        size: 14,
                        color: isFallback ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isFallback ? 'FALLBACK' : 'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isFallback ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    // Refresh will be handled by parent
                  },
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Real-time sentiment across top tokens',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (updatedTime != null)
                  Text(
                    '• Updated: $updatedTime',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            if (stats != null) ...[
              const SizedBox(height: 4),
              Text(
                '📊 ${stats!['realData'] ?? 0} real / ${stats!['fallbackData'] ?? 0} fallback',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isFallback ? Colors.orange : Colors.green,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (tokens.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No sentiment data available',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              _buildTokenGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenGrid(BuildContext context) {
    final tokenList = tokens.entries.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns: 2 for mobile, 3 for tablet, 4 for desktop, 5 for wide
        int cols;
        if (constraints.maxWidth > 900) {
          cols = 5;
        } else if (constraints.maxWidth > 700) {
          cols = 4;
        } else if (constraints.maxWidth > 500) {
          cols = 3;
        } else {
          cols = 2;
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tokenList.map((entry) {
            return SizedBox(
              width: (constraints.maxWidth - (12 * (cols - 1))) / cols,
              child: _buildTokenCard(context, entry.key, entry.value),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTokenCard(BuildContext context, String token, dynamic data) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final sentiment = data?['sentiment'];
    final positive = (sentiment?['positive'] as num?)?.toDouble() ?? 0.5;
    final sentimentDiff =
        (sentiment?['sentimentDiff'] as num?)?.toDouble() ?? 0;

    final vibeScore = (positive * 100).round();

    // Determine color based on sentiment
    Color sentimentColor;
    String sentimentLabel;

    if (vibeScore >= 70) {
      sentimentColor = Colors.green;
      sentimentLabel = '🟢 Bullish';
    } else if (vibeScore >= 40) {
      sentimentColor = Colors.orange;
      sentimentLabel = '🟡 Neutral';
    } else {
      sentimentColor = Colors.red;
      sentimentLabel = '🔴 Bearish';
    }

    return _PressableTokenCard(
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderColor: scheme.outlineVariant.withValues(alpha: 0.3),
      onTap: () {
        final coinGeckoId = _getCoinGeckoId(token);
        onTokenSelected(token, coinGeckoId);
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  token,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sentimentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$vibeScore',
                    style: TextStyle(
                      color: sentimentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Sentiment bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: positive,
                backgroundColor: Colors.red.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(sentimentColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sentimentLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: sentimentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (sentimentDiff != 0)
                  Text(
                    '${sentimentDiff >= 0 ? '+' : ''}${(sentimentDiff * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sentimentDiff >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getCoinGeckoId(String token) {
    final mapping = {
      'BTC': 'bitcoin',
      'BNB': 'binancecoin',
      'ETH': 'ethereum',
      'SOL': 'solana',
      'XRP': 'ripple',
      'DOGE': 'dogecoin',
      'SUI': 'sui',
      'USDT': 'tether',
    };
    return mapping[token.toUpperCase()] ?? token.toLowerCase();
  }
}

class _PressableTokenCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color backgroundColor;
  final Color borderColor;

  const _PressableTokenCard({
    required this.onTap,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  State<_PressableTokenCard> createState() => _PressableTokenCardState();
}

class _PressableTokenCardState extends State<_PressableTokenCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      scale: _pressed ? 0.985 : 1,
      child: AnimatedPhysicalModel(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        elevation: _pressed ? 1.5 : 4,
        color: widget.backgroundColor,
        shadowColor: Theme.of(context).shadowColor,
        shape: BoxShape.rectangle,
        borderRadius: radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            borderRadius: radius,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: widget.borderColor),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
