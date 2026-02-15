import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SentimentInsightsWidget extends StatelessWidget {
  final Map<String, dynamic> insightsData;
  
  const SentimentInsightsWidget({super.key, required this.insightsData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    final enhanced = insightsData['enhanced'];
    final vibeScore = insightsData['vibeScore'] ?? 50;
    final source = insightsData['source'] as String?;
    final timestamp = insightsData['timestamp'] as int?;
    final responseTimeMs = insightsData['responseTimeMs'] as int?;
    
    final isFallback = source == 'fallback';
    final updatedTime = timestamp != null 
        ? DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(timestamp))
        : null;
    
    if (enhanced == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📊 Sentiment Insights', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                'No enhanced data available. Using basic sentiment.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    
    final community = enhanced['community'] ?? {};
    final sentiment = enhanced['sentiment'] ?? {};
    final signals = enhanced['signals'] ?? {};
    
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
                    '📊 Sentiment Insights',
                    style: theme.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Source indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                Flexible(child: _buildVibeBadge(vibeScore, scheme)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Window: ${enhanced['window'] ?? 'Daily'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (updatedTime != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '• $updatedTime',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (responseTimeMs != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${responseTimeMs}ms)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            
            // Community Activity Section
            _buildSectionTitle(theme, '👥 Community Activity'),
            const SizedBox(height: 8),
            _buildMetricGrid(context, [
              _MetricItem('Messages', _formatNumber(community['totalMessages'] ?? 0)),
              _MetricItem('Interactions', _formatNumber(community['interactions'] ?? 0)),
              _MetricItem('Mentions', _formatNumber(community['mentions'] ?? 0)),
              _MetricItem('Unique Users', _formatNumber(community['uniqueUsers'] ?? 0)),
              _MetricItem('Communities', _formatNumber(community['activeCommunities'] ?? 0)),
            ]),
            
            const SizedBox(height: 20),
            
            // Sentiment Scores Section
            _buildSectionTitle(theme, '💭 Sentiment Scores'),
            const SizedBox(height: 8),
            _buildSentimentBar(context, 'Positive', (sentiment['positive'] ?? 0) * 100, Colors.green),
            const SizedBox(height: 8),
            _buildSentimentBar(context, 'Negative', (sentiment['negative'] ?? 0) * 100, Colors.red),
            const SizedBox(height: 8),
            _buildSentimentBar(context, 'Net Sentiment', ((sentiment['sentimentDiff'] ?? 0) + 1) * 50, 
              (sentiment['sentimentDiff'] ?? 0) >= 0 ? Colors.green : Colors.red),
            
            const SizedBox(height: 20),
            
            // Signals Section
            _buildSectionTitle(theme, '📈 Sentiment Signals'),
            const SizedBox(height: 8),
            _buildMetricGrid(context, [
              _MetricItem('Deviation', _formatSignal(signals['deviation'] ?? 0)),
              _MetricItem('Momentum', _formatSignal(signals['momentum'] ?? 0)),
              _MetricItem('Breakout', _formatSignal(signals['breakout'] ?? 0)),
              _MetricItem('Price Dislocation', _formatSignal(signals['priceDislocation'] ?? 0)),
            ]),
          ],
        ),
      ),
    );
  }
  
  Widget _buildVibeBadge(int score, ColorScheme scheme) {
    Color badgeColor;
    String label;
    
    if (score >= 70) {
      badgeColor = Colors.green;
      label = '🟢 Bullish';
    } else if (score >= 40) {
      badgeColor = Colors.orange;
      label = '🟡 Neutral';
    } else {
      badgeColor = Colors.red;
      label = '🔴 Bearish';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        '$label ($score)',
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
  
  Widget _buildMetricGrid(BuildContext context, List<_MetricItem> items) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items.map((item) => _buildMetricTile(context, item)).toList(),
    );
  }
  
  Widget _buildMetricTile(BuildContext context, _MetricItem item) {
    final theme = Theme.of(context);
    return Container(
      width: (MediaQuery.of(context).size.width - 80) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            item.value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSentimentBar(BuildContext context, String label, double percentage, Color color) {
    final theme = Theme.of(context);
    final clampedPercentage = percentage.clamp(0, 100);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            Text('${clampedPercentage.toStringAsFixed(1)}%', 
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clampedPercentage / 100,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
  
  String _formatNumber(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
  
  String _formatSignal(double value) {
    if (value.abs() >= 2) {
      return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)} ⚠️';
    }
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(2)}';
  }
}

class _MetricItem {
  final String label;
  final String value;
  
  _MetricItem(this.label, this.value);
}
