import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inspection.dart';
import '../models/inspection_photo.dart';
import '../models/job.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/glass_card.dart';
import 'camera_screen.dart';
import 'photo_detail_screen.dart';

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
          body: Column(
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
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filterCats(insp).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = _filterCats(insp)[i];
                      final active = cat == _filter;
                      // Calculate count for display
                      final count = cat == 'ALL'
                          ? insp.photos.length
                          : cat == 'FLAGGED'
                              ? insp.photos.where((p) => p.isFlagged).length
                              : insp.photos.where((p) => p.category == cat).length;
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
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: active
                                ? AppColors.primaryContainer
                                : AppColors.outlineVariant,
                          ),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? AppColors.primary
                                    : AppColors.outline,
                                letterSpacing: 0.4)),
                      ),
                    );
                  },
                ),
              ),
              ], // end if categories not empty
              const SizedBox(height: 8),
              // Photo grid
              Expanded(
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
                            photo: photos[i], index: i + 1),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final InspectionPhoto photo;
  final int index;
  const _PhotoTile({required this.photo, required this.index});

  Color _catColor(String cat) {
    if (cat == 'DAMAGE') return AppColors.onTertiaryContainer;
    return AppColors.outline;
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_full, color: AppColors.primary),
              title: const Text('View Photo',
                  style: TextStyle(color: AppColors.onSurface)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          PhotoDetailScreen(photo: photo, photoIndex: index)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete Photo',
                  style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: AppColors.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Delete Photo?',
                        style: TextStyle(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w700)),
                    content: const Text(
                        'This photo and its voice note will be permanently removed.',
                        style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.5)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx),
                        child: const Text('CANCEL',
                            style: TextStyle(
                                color: AppColors.outline, fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () async {
                          await context.read<AppProvider>().deletePhoto(
                              photo.jobId, photo.inspectionId, photo.id);
                          if (dCtx.mounted) Navigator.pop(dCtx);
                        },
                        child: const Text('DELETE',
                            style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                PhotoDetailScreen(photo: photo, photoIndex: index)),
      ),
      onLongPress: () => _showOptions(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            appImage(photo.imagePath,
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
                child: Text(photo.category,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _catColor(photo.category),
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
                  if (photo.isFlagged)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.onTertiaryContainer.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.flag, color: Colors.white, size: 11),
                    ),
                  if (photo.transcription != null && photo.transcription!.isNotEmpty)
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
          ],
        ),
      ),
    );
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
