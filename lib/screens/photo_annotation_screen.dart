import 'dart:math' show cos, sin;
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';

enum _Tool { freehand, line, arrow }

class _Stroke {
  final _Tool tool;
  final Color color;
  final double width;
  final List<Offset> points;
  const _Stroke(
      {required this.tool,
      required this.color,
      required this.width,
      required this.points});
}

class PhotoAnnotationScreen extends StatefulWidget {
  final String imagePath;
  final String photoId;
  final String jobId;
  final String inspectionId;

  const PhotoAnnotationScreen({
    super.key,
    required this.imagePath,
    required this.photoId,
    required this.jobId,
    required this.inspectionId,
  });

  @override
  State<PhotoAnnotationScreen> createState() =>
      _PhotoAnnotationScreenState();
}

class _PhotoAnnotationScreenState extends State<PhotoAnnotationScreen> {
  final _repaintKey = GlobalKey();
  final List<_Stroke> _strokes = [];
  _Stroke? _current;

  _Tool _tool = _Tool.freehand;
  Color _color = AppColors.onTertiaryContainer;
  double _strokeWidth = 3.0;
  bool _isSaving = false;

  static const _colors = [
    AppColors.onTertiaryContainer,
    AppColors.primaryContainer,
    Colors.white,
    Colors.black,
  ];

  // ── Gesture handlers ───────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d) {
    setState(() => _current = _Stroke(
          tool: _tool,
          color: _color,
          width: _strokeWidth,
          points: [d.localPosition],
        ));
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_current == null) return;
    final pt = d.localPosition;
    setState(() {
      _current = _Stroke(
        tool: _current!.tool,
        color: _current!.color,
        width: _current!.width,
        points: _current!.tool == _Tool.freehand
            ? [..._current!.points, pt]
            : [_current!.points.first, pt],
      );
    });
  }

  void _onPanEnd(DragEndDetails _) {
    if (_current != null && _current!.points.isNotEmpty) {
      setState(() {
        _strokes.add(_current!);
        _current = null;
      });
    }
  }

  void _undo() {
    if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await Future.delayed(const Duration(milliseconds: 50)); // let frame paint
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List bytes = byteData!.buffer.asUint8List();

      String path;
      if (kIsWeb) {
        // Web: can't write to file system — just return the original path
        // so the annotation visually shows but isn't persisted to disk
        path = widget.imagePath;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        path =
            '${dir.path}/annotated_${DateTime.now().millisecondsSinceEpoch}.png';
        await File(path).writeAsBytes(bytes);
        await context.read<AppProvider>().updatePhotoImage(
              widget.jobId, widget.inspectionId, widget.photoId, path);
      }

      if (mounted) Navigator.pop(context, path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: AppColors.surfaceContainerHigh,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(children: [
                      Icon(Icons.close, color: AppColors.onSurface),
                      SizedBox(width: 6),
                      Text('Cancel',
                          style: TextStyle(
                              color: AppColors.onSurface, fontSize: 15)),
                    ]),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _strokes.isEmpty ? null : _undo,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.undo,
                          color: _strokes.isEmpty
                              ? AppColors.outline
                              : AppColors.onSurface,
                          size: 22),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSaving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.onPrimary))
                          : const Text('SAVE',
                              style: TextStyle(
                                  color: AppColors.onPrimaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            // Drawing canvas
            Expanded(
              child: RepaintBoundary(
                key: _repaintKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    appImage(widget.imagePath, fit: BoxFit.contain),
                    GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: CustomPaint(
                        painter: _AnnotationPainter(
                            strokes: _strokes, current: _current),
                        size: Size.infinite,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Toolbar
            Container(
              color: AppColors.surfaceContainerHigh,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tools + thickness
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        _ToolBtn(
                            icon: Icons.draw_outlined, label: 'PEN',
                            selected: _tool == _Tool.freehand,
                            onTap: () => setState(() => _tool = _Tool.freehand)),
                        const SizedBox(width: 8),
                        _ToolBtn(
                            icon: Icons.horizontal_rule, label: 'LINE',
                            selected: _tool == _Tool.line,
                            onTap: () => setState(() => _tool = _Tool.line)),
                        const SizedBox(width: 8),
                        _ToolBtn(
                            icon: Icons.arrow_forward, label: 'ARROW',
                            selected: _tool == _Tool.arrow,
                            onTap: () => setState(() => _tool = _Tool.arrow)),
                      ]),
                      // Thickness dots
                      Row(
                        children: [2.0, 4.0, 7.0].map((w) {
                          final sel = _strokeWidth == w;
                          return GestureDetector(
                            onTap: () => setState(() => _strokeWidth = w),
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sel
                                    ? AppColors.primaryContainer.withOpacity(0.2)
                                    : Colors.transparent,
                                border: Border.all(
                                    color: sel
                                        ? AppColors.primaryContainer
                                        : AppColors.outlineVariant),
                              ),
                              child: Center(
                                child: Container(
                                    height: w, width: 16, color: _color),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Colors
                  Row(
                    children: _colors.map((c) {
                      final sel = _color == c;
                      return GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: sel ? Colors.white : Colors.transparent,
                                width: sel ? 3 : 0),
                            boxShadow: sel
                                ? [BoxShadow(
                                    color: c.withOpacity(0.5), blurRadius: 8)]
                                : [],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

class _AnnotationPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? current;
  const _AnnotationPainter({required this.strokes, this.current});

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in [...strokes, if (current != null) current!]) {
      _draw(canvas, s);
    }
  }

  void _draw(Canvas canvas, _Stroke s) {
    if (s.points.isEmpty) return;
    final paint = Paint()
      ..color = s.color
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (s.tool) {
      case _Tool.freehand:
        final path = Path()
          ..moveTo(s.points.first.dx, s.points.first.dy);
        for (final pt in s.points.skip(1)) {
          path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path, paint);
      case _Tool.line:
        if (s.points.length >= 2) {
          canvas.drawLine(s.points.first, s.points.last, paint);
        }
      case _Tool.arrow:
        if (s.points.length >= 2) {
          final start = s.points.first;
          final end = s.points.last;
          canvas.drawLine(start, end, paint);
          _arrowhead(canvas, end, end - start, paint);
        }
    }
  }

  void _arrowhead(Canvas canvas, Offset tip, Offset dir, Paint p) {
    final len = dir.distance;
    if (len < 1) return;
    final ux = dir.dx / len;
    final uy = dir.dy / len;
    const angle = 0.45;
    final headLen = p.strokeWidth * 5.0 + 8.0;
    final l = Offset(
      tip.dx - headLen * (ux * cos(angle) - uy * sin(angle)),
      tip.dy - headLen * (uy * cos(angle) + ux * sin(angle)),
    );
    final r = Offset(
      tip.dx - headLen * (ux * cos(angle) + uy * sin(angle)),
      tip.dy - headLen * (uy * cos(angle) - ux * sin(angle)),
    );
    canvas.drawLine(tip, l, p);
    canvas.drawLine(tip, r, p);
  }

  @override
  bool shouldRepaint(_AnnotationPainter _) => true;
}

// ── Tool button ───────────────────────────────────────────────────────────────

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToolBtn(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryContainer.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected
                    ? AppColors.primaryContainer
                    : AppColors.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: selected ? AppColors.primary : AppColors.outline,
                  size: 16),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : AppColors.outline,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
      );
}
