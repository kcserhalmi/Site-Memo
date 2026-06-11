import 'package:flutter/material.dart';

// BackdropFilter/blur removed — too expensive on iOS GPU.
// Solid semi-transparent surface achieves the same dark-glass look
// at a fraction of the render cost.
class GlassCard extends StatefulWidget {
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
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final br = widget.borderRadius ?? BorderRadius.circular(12);
    Widget card = AnimatedScale(
      scale: (_pressed && widget.onTap != null) ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 130),
      curve: const Cubic(0.23, 1.0, 0.32, 1.0),
      child: Container(
        decoration: BoxDecoration(
          color: widget.color ?? const Color(0xFF222221),
          borderRadius: br,
          border: Border.all(
            color: Colors.white.withOpacity(0.11),
            width: 0.5,
          ),
        ),
        padding: widget.padding ?? const EdgeInsets.all(16),
        child: widget.child,
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: card,
      );
    }
    return card;
  }
}
