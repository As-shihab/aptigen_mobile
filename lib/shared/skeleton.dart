import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// A `animate-pulse`-style placeholder block — opacity breathes on a loop,
/// mirroring the web app's `Pulse()` in MarketSkeletons.tsx. Used to build
/// section-shaped loading skeletons instead of a bare spinner.
class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool circle;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.circle = false,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 1, end: 0.4)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.slate800 : AppColors.slate100;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(opacity: _anim.value, child: child),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          shape: widget.circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: widget.circle
              ? null
              : (widget.borderRadius ?? BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
