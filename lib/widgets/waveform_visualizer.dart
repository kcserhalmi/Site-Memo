import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _build();
  }

  void _build() {
    _controllers = List.generate(widget.barCount, (i) {
      final ms = 400 + _rng.nextInt(500);
      return AnimationController(
          vsync: this, duration: Duration(milliseconds: ms));
    });
    _animations = _controllers
        .map((c) => Tween<double>(begin: 3, end: widget.height * 0.85)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();
    if (widget.isActive) {
      for (final c in _controllers) {
        c.repeat(reverse: true);
      }
    }
  }

  @override
  void didUpdateWidget(WaveformVisualizer old) {
    super.didUpdateWidget(old);
    if (widget.isActive != old.isActive) {
      for (final c in _controllers) {
        if (widget.isActive) {
          c.repeat(reverse: true);
        } else {
          c.stop();
          c.animateTo(0.15);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    return SizedBox(
      height: widget.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.barCount, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (_, __) => Container(
              width: 3,
              height: widget.isActive ? _animations[i].value : 4,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          );
        }),
      ),
    );
  }
}
