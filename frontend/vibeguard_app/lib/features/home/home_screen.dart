import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/vibe_provider.dart';
import '../dashboard/vibe_meter_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _tokenController = TextEditingController(text: 'BTC');
  final _tokenIdController = TextEditingController(text: 'bitcoin');

  @override
  Widget build(BuildContext context) {
    final vibeState = ref.watch(vibeNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛡️ VibeGuard AI'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Token Symbol',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tokenIdController,
                      decoration: const InputDecoration(
                        labelText: 'CoinGecko ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: vibeState.isLoading
                          ? null
                          : () {
                              ref.read(vibeNotifierProvider.notifier).checkVibe(
                                    _tokenController.text,
                                    _tokenIdController.text,
                                  );
                            },
                      child: vibeState.isLoading
                          ? const CircularProgressIndicator()
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
            if (vibeState.result != null) ...[
              VibeMeterWidget(result: vibeState.result!),
              const SizedBox(height: 16),
              _buildAnalysisCard(vibeState.result!),
            ],
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
            Text('Action: ${result.analysis.shouldExit ? "🚨 EXIT" : "✅ HOLD"}'),
            const SizedBox(height: 8),
            Text(result.analysis.reason),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _tokenIdController.dispose();
    super.dispose();
  }
}
