import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// Single AnimationController drives all bars via math offsets.
// Previously used barCount individual controllers — too heavy for iOS.
class WaveformVisualizer extends StatefulWidget {
  final bool isActive;
  final int barCount;
  final Color? color;
  final double height;

  const WaveformVisualizer({
    super.key,
    required this.isActive,
    this.barCount = 14,
    this.color,
    this.height = 32,
  });

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isActive) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(WaveformVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      if (widget.isActive) {
        _ctrl.repeat();
      } else {
        _ctrl.stop();
        _ctrl.animateTo(0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value * 2 * pi;
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              final phase = i * (2 * pi / widget.barCount);
              final normalized = widget.isActive
                  ? (sin(t + phase) + 1) / 2
                  : 0.15;
              final h = (normalized * widget.height * 0.85)
                  .clamp(3.0, widget.height * 0.85);
              return Container(
                width: 3,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
