import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Animated Agent Profile Dialog with pulsing glow effect on avatar border.
class AgentProfileDialog extends StatefulWidget {
  final ColorScheme scheme;
  final TextTheme textTheme;
  final String agentName;
  final String flavorText;
  final String strategyLabel;
  final Color borderColor;
  final String avatarPath;
  final String statusIndicator;
  final String protectionStatus;
  final String gasTank;
  final bool step1Done;
  final bool step2Done;
  final String userAddress;
  final String userWbnb;

  const AgentProfileDialog({
    super.key,
    required this.scheme,
    required this.textTheme,
    required this.agentName,
    required this.flavorText,
    required this.strategyLabel,
    required this.borderColor,
    required this.avatarPath,
    required this.statusIndicator,
    required this.protectionStatus,
    required this.gasTank,
    required this.step1Done,
    required this.step2Done,
    required this.userAddress,
    required this.userWbnb,
  });

  @override
  State<AgentProfileDialog> createState() => _AgentProfileDialogState();
}

class _AgentProfileDialogState extends State<AgentProfileDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.15, end: 0.45).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  String _short(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final textTheme = widget.textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;
    final avatarSize = isCompact ? 140.0 : 180.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 20,
        vertical: isCompact ? 16 : 24,
      ),
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 16 : 24,
            16,
            isCompact ? 16 : 24,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Animated circular avatar with pulsing glow
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.borderColor,
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.borderColor
                              .withValues(alpha: _glowAnimation.value),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: ClipOval(
                  child: Image.asset(
                    widget.avatarPath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: scheme.surfaceContainerHighest
                            .withValues(alpha: 0.35),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.shield_outlined,
                          size: 72,
                          color: scheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Agent name
              Text(
                widget.agentName,
                textAlign: TextAlign.center,
                style: (isCompact
                        ? textTheme.headlineSmall
                        : textTheme.headlineMedium)
                    ?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),

              // Strategy label
              Text(
                'Strategy: ${widget.strategyLabel}',
                textAlign: TextAlign.center,
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 14),

              // Flavor text / Lore
              Text(
                widget.flavorText,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 18),

              Divider(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
                height: 1,
              ),
              const SizedBox(height: 18),

              // RPG-style stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatChip(
                    icon: Icons.circle,
                    iconColor:
                        widget.step2Done ? Colors.green : Colors.amber,
                    label: widget.statusIndicator,
                    textTheme: textTheme,
                    scheme: scheme,
                  ),
                  _StatChip(
                    icon: Icons.shield,
                    iconColor:
                        widget.step2Done ? scheme.primary : Colors.grey,
                    label: widget.protectionStatus,
                    textTheme: textTheme,
                    scheme: scheme,
                  ),
                  _StatChip(
                    icon: Icons.local_gas_station,
                    iconColor: scheme.primary,
                    label: widget.gasTank,
                    textTheme: textTheme,
                    scheme: scheme,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Divider(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
                height: 1,
              ),
              const SizedBox(height: 16),

              // Wallet info
              if (widget.step2Done)
                Text(
                  'Wallet: ${_short(widget.userAddress)}',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      'Wallet: ${_short(widget.userAddress)}',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Complete 2 steps to activate protection',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: widget.userAddress));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Wallet address copied'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('Copy Address'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon:
                          const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final TextTheme textTheme;
  final ColorScheme scheme;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.textTheme,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
