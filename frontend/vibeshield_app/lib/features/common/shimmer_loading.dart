import 'package:flutter/material.dart';

class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFF2A2A2A),
                Color(0xFF3A3A3A),
                Color(0xFF4A4A4A),
                Color(0xFF3A3A3A),
                Color(0xFF2A2A2A),
              ],
              stops: [
                0.0,
                (_animation.value + 2) / 4 - 0.3,
                (_animation.value + 2) / 4,
                (_animation.value + 2) / 4 + 0.3,
                1.0,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
              transform: GradientRotation(_animation.value * 0.5),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}


class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton card for sentiment tokens
class SkeletonTokenCard extends StatelessWidget {
  const SkeletonTokenCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SkeletonBox(width: 50, height: 18),
                Container(
                  width: 36,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const SkeletonBox(width: double.infinity, height: 6, borderRadius: 3),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonBox(width: 60, height: 14),
                SkeletonBox(width: 45, height: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton card for market pulse
class SkeletonMarketTile extends StatelessWidget {
  const SkeletonMarketTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(width: 40, height: 18),
            SizedBox(height: 8),
            SkeletonBox(width: 70, height: 16),
            SizedBox(height: 8),
            SkeletonBox(width: 55, height: 14),
          ],
        ),
      ),
    );
  }
}
