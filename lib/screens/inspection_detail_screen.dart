import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/inspection.dart';
import '../models/inspection_photo.dart';
import '../models/job.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/glass_card.dart';
import 'camera_screen.dart';
import 'photo_detail_screen.dart';
import '../services/export_service.dart';

class InspectionDetailScreen extends StatefulWidget {
  final Job job;
  final Inspection inspection;
  const InspectionDetailScreen(
      {super.key, required this.job, required this.inspection});

  @override
  State<InspectionDetailScreen> createState() =>
      _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  String _filter = 'ALL';
  final Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  Future<void> _shareSelected(List<InspectionPhoto> allPhotos) async {
    final selected = allPhotos.where((p) => _selectedIds.contains(p.id)).toList();
    if (selected.isEmpty) return;
    try {
      await Share.shareXFiles(
        selected.map((p) => XFile(p.imagePath)).toList(),
        subject: 'Site Memo Photos',
      );
    } catch (_) {}
    _clearSelection();
  }

  Future<void> _deleteSelected(BuildContext context, String jobId,
      String inspId, List<InspectionPhoto> allPhotos) async {
    final toDelete = allPhotos.where((p) => _selectedIds.contains(p.id)).toList();
    final count = toDelete.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $count photo${count == 1 ? '' : 's'}?',
            style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('CANCEL', style: TextStyle(color: AppColors.outline, fontSize: 12))),
          TextButton(onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('DELETE', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;
    final provider = context.read<AppProvider>();
    for (final p in toDelete) {
      await provider.deletePhoto(jobId, inspId, p.id);
    }
    _clearSelection();
  }

  List<String> _filterCats(Inspection insp) =>
      ['ALL', 'FLAGGED', ...insp.categories];

  List<InspectionPhoto> _getFiltered(Inspection insp) {
    if (_filter == 'ALL') return insp.photos;
    if (_filter == 'FLAGGED') return insp.photos.where((p) => p.isFlagged).toList();
    return insp.photos.where((p) => p.category == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (_, provider, __) {
        final job = provider.jobs.firstWhere((j) => j.id == widget.job.id,
            orElse: () => widget.job);
        final insp = job.inspections.firstWhere(
            (i) => i.id == widget.inspection.id,
            orElse: () => widget.inspection);
        final photos = _getFiltered(insp);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insp.title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface)),
                Text(insp.dateLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.ios_share, color: AppColors.outline),
                color: AppColors.surfaceContainerHigh,
                tooltip: 'Export',
                onSelected: (v) async {
                  if (v == 'pdf') {
                    await ExportService.exportPdf(job, insp);
                  } else if (v == 'zip') {
                    await ExportService.exportZip(job, insp);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'pdf',
                    child: Row(children: [
                      Icon(Icons.picture_as_pdf_outlined,
                          color: AppColors.onTertiaryContainer, size: 16),
                      SizedBox(width: 10),
                      Text('Export PDF',
                          style: TextStyle(color: AppColors.onSurface)),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'zip',
                    child: Row(children: [
                      Icon(Icons.folder_zip_outlined,
                          color: AppColors.primary, size: 16),
                      SizedBox(width: 10),
                      Text('Export ZIP (photos + notes)',
                          style: TextStyle(color: AppColors.onSurface)),
                    ]),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_a_photo_outlined,
                    color: AppColors.primary),
                onPressed: () {
                  // Set this inspection as the active context
                  provider.setSelectedContext(job.id, insp.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CameraScreen(
                          jobId: job.id, inspectionId: insp.id),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Stack(children: [Column(
            children: [
              // Inspector + stats row
              if (insp.inspector.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            color: AppColors.outline, size: 16),
                        const SizedBox(width: 8),
                        Text(insp.inspector,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.onSurfaceVariant)),
                        const Spacer(),
                        Text('${insp.photoCount} photos',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.outline)),
                      ],
                    ),
                  ),
                ),
              // Notes field
              _NotesCard(insp: insp, jobId: job.id),
              // Tags quick-access row
              _InspectionTagsRow(
                insp: insp,
                jobId: job.id,
                onChanged: () => setState(() {
                  // reset filter if selected tag was removed
                  if (!_filterCats(insp).contains(_filter)) _filter = 'ALL';
                }),
              ),
              // Category filter strip
              if (insp.categories.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: 40,
                  child: Builder(builder: (ctx) {
                    // Compute once per build — not per filter chip
                    final filterCats = _filterCats(insp);
                    final counts = <String, int>{
                      'ALL': insp.photos.length,
                      'FLAGGED': insp.photos.where((p) => p.isFlagged).length,
                      for (final c in insp.categories)
                        c: insp.photos.where((p) => p.category == c).length,
                    };
                    return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filterCats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = filterCats[i];
                      final active = cat == _filter;
                      final count = counts[cat] ?? 0;
                      final label = count > 0 ? '$cat  $count' : cat;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.primaryContainer.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active
                                ? AppColors.primaryContainer
                                : AppColors.outlineVariant,
                          ),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? AppColors.primary
                                    : AppColors.outline,
                                letterSpacing: 0.2)),
                      ),
                    );
                  },
                ); // ListView.separated
                  }), // Builder
              ),
              ], // end if categories not empty
              const SizedBox(height: 8),
              // Photo grid — wrapped in RepaintBoundary so notes/tags
              // above don't repaint when photos change
              Expanded(
                child: RepaintBoundary(
                child: photos.isEmpty
                    ? _EmptyPhotos(
                        onCapture: () {
                          provider.setSelectedContext(job.id, insp.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CameraScreen(
                                  jobId: job.id, inspectionId: insp.id),
                            ),
                          );
                        },
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: photos.length,
                        itemBuilder: (_, i) => _PhotoTile(
                            photo: photos[i], index: i,
                            allPhotos: photos,
                            isSelecting: _isSelecting,
                            isSelected: _selectedIds.contains(photos[i].id),
                            onLongPress: () => _toggleSelect(photos[i].id),
                            onSelectTap: () => _toggleSelect(photos[i].id)),
                      ),
                ), // RepaintBoundary
              ),
            ],
          ), // Column
          // ── Multi-select action bar (Positioned at bottom of Stack) ──────
          if (_isSelecting)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                color: AppColors.surfaceContainer,
                padding: EdgeInsets.fromLTRB(16, 12, 16,
                    12 + MediaQuery.of(context).padding.bottom),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _clearSelection,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.close, color: AppColors.outline, size: 14),
                          const SizedBox(width: 6),
                          Text('${_selectedIds.length} selected',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface)),
                        ]),
                      ),
                    ),
                    const Spacer(),
                    _ActionBtn(icon: Icons.ios_share, label: 'Share',
                        onTap: () => _shareSelected(photos)),
                    const SizedBox(width: 8),
                    _ActionBtn(icon: Icons.delete_outline, label: 'Delete',
                        color: AppColors.error,
                        onTap: () => _deleteSelected(context, job.id, insp.id, photos)),
                  ],
                ),
              ),
            ),
          ]), // Stack
        );
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionBtn({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: (color ?? AppColors.outline).withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color ?? AppColors.onSurface, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: color ?? AppColors.onSurface)),
          ]),
        ),
      );
}

class _PhotoTile extends StatefulWidget {
  final InspectionPhoto photo;
  final int index;
  final List<InspectionPhoto> allPhotos;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onSelectTap;
  const _PhotoTile({
    required this.photo, required this.index, required this.allPhotos,
    this.isSelecting = false, this.isSelected = false,
    required this.onLongPress, required this.onSelectTap,
  });

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  bool _pressed = false;

  Color _catColor(String cat) {
    if (cat == 'DAMAGE') return AppColors.onTertiaryContainer;
    return AppColors.outline;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
      onTap: () {
        if (widget.isSelecting) {
          widget.onSelectTap();
        } else {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => PhotoDetailScreen(photos: widget.allPhotos, initialIndex: widget.index)));
        }
      },
      onLongPress: widget.isSelecting ? null : () { widget.onLongPress(); },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: const Cubic(0.23, 1.0, 0.32, 1.0),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            appImage(widget.photo.imagePath,
                cacheWidth: 400,
                networkUrl: widget.photo.storageUrl,
                fallback: Container(
                  color: AppColors.surfaceContainerHigh,
                  child:
                      const Icon(Icons.image, color: AppColors.outline, size: 40),
                )),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(widget.photo.category,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _catColor(widget.photo.category),
                        letterSpacing: 0.3)),
              ),
            ),
            // Top-right indicators
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.photo.isFlagged)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.onTertiaryContainer.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.flag, color: Colors.white, size: 11),
                    ),
                  if (widget.photo.transcription != null && widget.photo.transcription!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.mic, color: AppColors.primary, size: 11),
                    ),
                ],
              ),
            ),
            // Selection overlay — inside Stack children
            if (widget.isSelecting)
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppColors.primaryContainer.withOpacity(0.35)
                        : Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: widget.isSelected
                        ? Border.all(color: AppColors.primaryContainer, width: 2.5)
                        : null,
                  ),
                  child: widget.isSelected
                      ? const Center(
                          child: Icon(Icons.check_circle,
                              color: AppColors.primaryContainer, size: 32),
                        )
                      : null,
                ),
              ),
          ], // Stack children
        ), // Stack
        ), // ClipRRect
      ), // AnimatedScale
    ), // GestureDetector
    ); // RepaintBoundary
  }
}

// ── Per-inspection tag quick-access row ──────────────────────────────────────

// ── Notes card ───────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  final Inspection insp;
  final String jobId;
  const _NotesCard({required this.insp, required this.jobId});

  void _edit(BuildContext context) {
    final ctrl = TextEditingController(text: insp.notes);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Inspection Notes',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                TextButton(
                  onPressed: () async {
                    await context
                        .read<AppProvider>()
                        .updateNotes(jobId, insp.id, ctrl.text.trim());
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Notes saved'),
                        backgroundColor: AppColors.surfaceContainerHigh,
                        duration: Duration(seconds: 2),
                      ));
                    }
                  },
                  child: const Text('SAVE',
                      style: TextStyle(
                          color: AppColors.primaryContainer,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(
                  color: AppColors.onSurface, fontSize: 14, height: 1.5),
              cursorColor: AppColors.primary,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                hintText:
                    'Site conditions, access notes, general observations…',
                hintStyle: TextStyle(
                    color: AppColors.outline, fontSize: 13),
                filled: true,
                fillColor: AppColors.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNotes = insp.notes.isNotEmpty;
    return GestureDetector(
      onTap: () => _edit(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: hasNotes
                ? AppColors.surfaceContainerHigh
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: hasNotes
                    ? AppColors.outlineVariant
                    : AppColors.outlineVariant.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                hasNotes ? Icons.notes : Icons.add_comment_outlined,
                color: hasNotes ? AppColors.onSurfaceVariant : AppColors.outline,
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasNotes ? insp.notes : 'Add inspection notes…',
                  style: TextStyle(
                      fontSize: 13,
                      color: hasNotes
                          ? AppColors.onSurfaceVariant
                          : AppColors.outline,
                      fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.edit_outlined, color: AppColors.outline, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectionTagsRow extends StatelessWidget {
  final Inspection insp;
  final String jobId;
  final VoidCallback onChanged;
  const _InspectionTagsRow(
      {required this.insp, required this.jobId, required this.onChanged});

  void _openSheet(BuildContext context) {
    final cats = List<String>.from(insp.categories);
    final addCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tags',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  TextButton(
                    onPressed: () async {
                      await context
                          .read<AppProvider>()
                          .updateInspectionCategories(jobId, insp.id, cats);
                      if (ctx.mounted) Navigator.pop(ctx);
                      onChanged();
                    },
                    child: const Text('DONE',
                        style: TextStyle(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const Text('Tap × on a tag to remove it',
                  style: TextStyle(fontSize: 12, color: AppColors.outline)),
              const SizedBox(height: 14),
              if (cats.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cats
                      .map((t) => GestureDetector(
                            onTap: () => setModal(() => cats.remove(t)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                    color: AppColors.primaryContainer
                                        .withOpacity(0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(t,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary)),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.close,
                                      size: 12, color: AppColors.outline),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: addCtrl,
                      style: const TextStyle(
                          color: AppColors.onSurface, fontSize: 14),
                      cursorColor: AppColors.primary,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (v) {
                        final tag = v.trim().toUpperCase();
                        if (tag.isNotEmpty && !cats.contains(tag)) {
                          setModal(() {
                            cats.add(tag);
                            addCtrl.clear();
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'Add a tag…',
                        hintStyle: TextStyle(
                            color: AppColors.outline, fontSize: 13),
                        enabledBorder: UnderlineInputBorder(
                            borderSide:
                                BorderSide(color: AppColors.outlineVariant)),
                        focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: AppColors.primaryContainer, width: 2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      final tag = addCtrl.text.trim().toUpperCase();
                      if (tag.isNotEmpty && !cats.contains(tag)) {
                        setModal(() {
                          cats.add(tag);
                          addCtrl.clear();
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimaryContainer,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    child: const Text('ADD',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            GestureDetector(
              onTap: () => _openSheet(context),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: AppColors.primaryContainer.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label_outline,
                        color: AppColors.primaryFixedDim, size: 14),
                    SizedBox(width: 5),
                    Text('EDIT TAGS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryFixedDim,
                            letterSpacing: 0.4)),
                  ],
                ),
              ),
            ),
            ...insp.categories.map((cat) => GestureDetector(
                  onTap: () => _openSheet(context),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Text(cat,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant)),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _EmptyPhotos extends StatelessWidget {
  final VoidCallback onCapture;
  const _EmptyPhotos({required this.onCapture});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_camera_outlined,
                color: AppColors.outline, size: 56),
            const SizedBox(height: 16),
            const Text('No photos yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCapture,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryContainer,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_a_photo, size: 18),
              label: const Text('ADD PHOTO',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
