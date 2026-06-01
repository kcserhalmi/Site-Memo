import 'package:flutter/material.dart';

// BackdropFilter/blur removed — too expensive on iOS GPU.
// Solid semi-transparent surface achieves the same dark-glass look
// at a fraction of the render cost.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(12);
    Widget card = Container(
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF222221),
        borderRadius: br,
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
          width: 1,
        ),
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
