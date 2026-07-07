import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../models/inspection.dart';
import '../models/inspection_photo.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/app_prefs.dart';
import '../utils/file_utils.dart';
import '../widgets/glass_card.dart';
import 'inspection_detail_screen.dart';
import 'photo_detail_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;
  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _showTimeline = false;

  // ── New Inspection dialog ──────────────────────────────────────────────────
  void _newInspection(BuildContext context) async {
    final savedName = await AppPrefs.getInspectorName();
    final titleCtrl = TextEditingController();
    final inspCtrl = TextEditingController(text: savedName);
    final tagCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    final List<String> tags = [];

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
              left: 20, right: 20, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Inspection',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface)),
              const SizedBox(height: 20),
              _Field(controller: titleCtrl, label: 'Title (e.g. Foundation check)'),
              const SizedBox(height: 14),
              _Field(controller: inspCtrl, label: 'Inspector name'),
              const SizedBox(height: 14),
              // Date picker row
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (_, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AppColors.primaryContainer,
                          onPrimary: AppColors.onPrimaryContainer,
                          surface: AppColors.surfaceContainerHigh,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setModal(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.outline, size: 16),
                      const SizedBox(width: 10),
                      Text(
                        _formatDate(selectedDate),
                        style: const TextStyle(
                            color: AppColors.onSurface, fontSize: 14),
                      ),
                      const Spacer(),
                      const Icon(Icons.edit_outlined,
                          color: AppColors.outline, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // ── Tags builder ────────────────────────────────────────────
              const Text('TAGS',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.outline,
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              // Added tags as chips
              if (tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map((t) => GestureDetector(
                            onTap: () => setModal(() => tags.remove(t)),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                    color: AppColors.primaryContainer
                                        .withOpacity(0.4)),
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
                const SizedBox(height: 10),
              ],
              // Tag input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tagCtrl,
                      style: const TextStyle(
                          color: AppColors.onSurface, fontSize: 14),
                      cursorColor: AppColors.primary,
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (v) {
                        final tag = v.trim().toUpperCase();
                        if (tag.isNotEmpty && !tags.contains(tag)) {
                          setModal(() {
                            tags.add(tag);
                            tagCtrl.clear();
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'e.g. UNIT 201, EXTERIOR, PLUMBING…',
                        hintStyle: TextStyle(
                            color: AppColors.outline, fontSize: 12),
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
                      final tag = tagCtrl.text.trim().toUpperCase();
                      if (tag.isNotEmpty && !tags.contains(tag)) {
                        setModal(() {
                          tags.add(tag);
                          tagCtrl.clear();
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
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleCtrl.text.trim().isEmpty
                        ? 'Inspection'
                        : titleCtrl.text.trim();
                    final insp = await context.read<AppProvider>().createInspection(
                          jobId: widget.job.id,
                          title: title,
                          inspector: inspCtrl.text.trim(),
                          date: selectedDate,
                          categories: List.from(tags),
                        );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => InspectionDetailScreen(
                                  job: widget.job,
                                  inspection: insp,
                                )),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('CREATE & OPEN',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit inspection dialog ─────────────────────────────────────────────────
  void _editInspection(BuildContext context, Inspection insp) {
    final titleCtrl = TextEditingController(text: insp.title);
    final inspCtrl = TextEditingController(text: insp.inspector);
    DateTime selectedDate = insp.date;

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
              left: 20, right: 20, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Inspection',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: ctx,
                        builder: (dCtx) => AlertDialog(
                          backgroundColor: AppColors.surfaceContainerHigh,
                          title: const Text('Delete Inspection',
                              style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700)),
                          content: Text('Delete "${insp.title}"? This removes all ${insp.photoCount} photos.',
                              style: const TextStyle(color: AppColors.onSurfaceVariant)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx),
                                child: const Text('CANCEL', style: TextStyle(color: AppColors.outline))),
                            TextButton(
                              onPressed: () async {
                                await context.read<AppProvider>().deleteInspection(widget.job.id, insp.id);
                                if (dCtx.mounted) Navigator.pop(dCtx);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                              child: const Text('DELETE', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('DELETE',
                        style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Field(controller: titleCtrl, label: 'Title'),
              const SizedBox(height: 14),
              _Field(controller: inspCtrl, label: 'Inspector name'),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (_, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: AppColors.primaryContainer,
                          surface: AppColors.surfaceContainerHigh,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setModal(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: AppColors.outline, size: 16),
                      const SizedBox(width: 10),
                      Text(_formatDate(selectedDate),
                          style: const TextStyle(color: AppColors.onSurface, fontSize: 14)),
                      const Spacer(),
                      const Icon(Icons.edit_outlined, color: AppColors.outline, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    await context.read<AppProvider>().editInspection(
                          widget.job.id, insp.id,
                          titleCtrl.text.trim().isEmpty ? 'Inspection' : titleCtrl.text.trim(),
                          inspCtrl.text.trim(),
                          selectedDate,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _cycleStatus(BuildContext context, Inspection insp) {
    const order = ['in_progress', 'submitted', 'approved'];
    final next = order[(order.indexOf(insp.status) + 1) % order.length];
    context.read<AppProvider>().updateInspectionStatus(widget.job.id, insp.id, next);
  }

  String _formatDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (_, provider, __) {
        final job = provider.jobs.firstWhere((j) => j.id == widget.job.id,
            orElse: () => widget.job);
        final sorted = [...job.inspections]
          ..sort((a, b) => b.date.compareTo(a.date));

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
                Text(job.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                Text(job.location,
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant)),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.outline),
                color: AppColors.surfaceContainerHigh,
                onSelected: (v) {
                  if (v == 'complete') {
                    provider.completeJob(job.id);
                    Navigator.pop(context);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'complete', child: Row(children: [
                    Icon(Icons.check_circle_outline, color: AppColors.secondary, size: 16),
                    SizedBox(width: 10),
                    Text('Mark Complete', style: TextStyle(color: AppColors.onSurface)),
                  ])),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Stats row (2 boxes only)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _StatBox(label: 'INSPECTIONS', value: '${job.inspectionCount}'),
                    const SizedBox(width: 8),
                    _StatBox(label: 'TOTAL PHOTOS', value: '${job.photoCount}'),
                  ],
                ),
              ),
              // View toggle: inspections list vs chronological photo timeline
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    _ViewToggleBtn(
                      label: 'INSPECTIONS',
                      icon: Icons.assignment_outlined,
                      active: !_showTimeline,
                      onTap: () => setState(() => _showTimeline = false),
                    ),
                    const SizedBox(width: 8),
                    _ViewToggleBtn(
                      label: 'TIMELINE',
                      icon: Icons.photo_library_outlined,
                      active: _showTimeline,
                      onTap: () => setState(() => _showTimeline = true),
                    ),
                  ],
                ),
              ),
              // Inspection list or photo timeline
              Expanded(
                child: _showTimeline
                    ? _TimelineView(job: job)
                    : sorted.isEmpty
                        ? _EmptyInspections(onNew: () => _newInspection(context))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: sorted.length,
                            itemBuilder: (_, i) => _InspectionCard(
                              inspection: sorted[i],
                              job: job,
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => InspectionDetailScreen(
                                      job: job, inspection: sorted[i]))),
                              onEdit: () => _editInspection(context, sorted[i]),
                              onStatusTap: () => _cycleStatus(context, sorted[i]),
                            ),
                          ),
              ),
            ],
          ),
          floatingActionButton: job.status == 'active'
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width - 32,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // NEW INSPECTION — primary action
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () => _newInspection(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: AppColors.onPrimaryContainer,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 8,
                              shadowColor: AppColors.primaryContainer.withOpacity(0.4),
                            ),
                            icon: const Icon(Icons.add, size: 20),
                            label: const Text('NEW INSPECTION',
                                style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // COMPLETE JOB — secondary action
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  backgroundColor: AppColors.surfaceContainerHigh,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Complete this job?',
                                      style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w700)),
                                  content: const Text(
                                      'The job moves to Completed. All inspections and photos are kept.',
                                      style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13, height: 1.5)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx),
                                      child: const Text('CANCEL', style: TextStyle(color: AppColors.outline, fontSize: 12)),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await provider.completeJob(job.id);
                                        if (dCtx.mounted) Navigator.pop(dCtx);
                                        if (context.mounted) Navigator.pop(context);
                                      },
                                      child: const Text('COMPLETE',
                                          style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.outline,
                              side: const BorderSide(color: AppColors.outlineVariant),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('COMPLETE JOB',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ViewToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ViewToggleBtn(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primaryContainer.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active
                      ? AppColors.primaryContainer.withOpacity(0.6)
                      : AppColors.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: active ? AppColors.primary : AppColors.outline,
                    size: 14),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: active ? AppColors.primary : AppColors.outline,
                        letterSpacing: 0.4)),
              ],
            ),
          ),
        ),
      );
}

// ── Timeline: chronological photo feed across all inspections ────────────────

class _TimelineView extends StatelessWidget {
  final Job job;
  const _TimelineView({required this.job});

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    // Flatten all photos across inspections, newest first
    final all = <InspectionPhoto>[];
    for (final insp in job.inspections) {
      all.addAll(insp.photos);
    }
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (all.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined,
                color: AppColors.outline, size: 56),
            SizedBox(height: 16),
            Text('No photos yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant)),
            SizedBox(height: 8),
            Text('Photos from every inspection will\nappear here in order.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.outline)),
          ],
        ),
      );
    }

    // Group into day sections (list stays sorted, so sections are ordered)
    final sections = <MapEntry<String, List<InspectionPhoto>>>[];
    for (final p in all) {
      final label = _dayLabel(p.timestamp);
      if (sections.isEmpty || sections.last.key != label) {
        sections.add(MapEntry(label, [p]));
      } else {
        sections.last.value.add(p);
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: sections.length,
      itemBuilder: (_, si) {
        final section = sections[si];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Row(
                children: [
                  Text(section.key.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryFixedDim,
                          letterSpacing: 0.5)),
                  const SizedBox(width: 8),
                  Text('${section.value.length}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.outline)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Container(
                          height: 0.5, color: AppColors.outlineVariant)),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: section.value.length,
              itemBuilder: (_, i) {
                final photo = section.value[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PhotoDetailScreen(
                            photos: all, initialIndex: all.indexOf(photo))),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        appImage(photo.imagePath,
                            cacheWidth: 300,
                            networkUrl: photo.storageUrl,
                            fallback: Container(
                                color: AppColors.surfaceContainerHigh,
                                child: const Icon(Icons.image,
                                    color: AppColors.outline, size: 24))),
                        if (photo.isFlagged)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.onTertiaryContainer
                                    .withOpacity(0.85),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.flag,
                                  color: Colors.white, size: 10),
                            ),
                          ),
                        Positioned(
                          bottom: 5,
                          left: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(photo.category,
                                style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                    letterSpacing: 0.2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
          ],
        );
      },
    );
  }
}

class _InspectionCard extends StatelessWidget {
  final Inspection inspection;
  final Job job;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onStatusTap;
  const _InspectionCard({required this.inspection, required this.job, required this.onTap, required this.onEdit, required this.onStatusTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date badge
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryContainer.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    _month(inspection.date),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primaryFixedDim, letterSpacing: 0.5),
                  ),
                  Text(
                    '${inspection.date.day}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary, height: 1.1),
                  ),
                  Text(
                    '${inspection.date.year}',
                    style: const TextStyle(fontSize: 9, color: AppColors.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inspection.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                  if (inspection.inspector.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 12, color: AppColors.outline),
                        const SizedBox(width: 4),
                        Text(inspection.inspector,
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Pill('${inspection.photoCount} photos', AppColors.outline),
                      if (inspection.flaggedCount > 0) ...[
                        const SizedBox(width: 6),
                        _Pill('${inspection.flaggedCount} flagged',
                            AppColors.onTertiaryContainer),
                      ],
                      const SizedBox(width: 6),
                      _StatusPill(
                        status: inspection.status,
                        onTap: onStatusTap,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Edit button
            GestureDetector(
              onTap: onEdit,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.edit_outlined, color: AppColors.outline, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _month(DateTime d) {
    const m = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
    return m[d.month - 1];
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.outline, letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
            ],
          ),
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _Field({required this.controller, required this.label});
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        style: const TextStyle(color: AppColors.onSurface),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.outline, fontSize: 13),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.outlineVariant)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryContainer, width: 2)),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  final String status;
  final VoidCallback onTap;
  const _StatusPill({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = status == 'approved'
        ? 'APPROVED'
        : status == 'submitted'
            ? 'SUBMITTED'
            : 'IN PROGRESS';
    final color = status == 'approved'
        ? AppColors.secondary
        : status == 'submitted'
            ? const Color(0xFF64B5F6)
            : AppColors.primaryFixedDim;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.3)),
      ),
    );
  }
}

class _EmptyInspections extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyInspections({required this.onNew});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open_outlined, color: AppColors.outline, size: 56),
            const SizedBox(height: 16),
            const Text('No inspections yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 8),
            const Text('Create your first inspection to start capturing', style: TextStyle(fontSize: 13, color: AppColors.outline)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('NEW INSPECTION', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
