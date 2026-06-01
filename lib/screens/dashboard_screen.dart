import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import 'flagged_screen.dart';
import 'job_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback? onOpenAccount;
  const DashboardScreen({super.key, this.onOpenAccount});

  void _newInspection(BuildContext context) {
    final nameCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Site',
            style: TextStyle(
                color: AppColors.onSurface, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Field(controller: nameCtrl, label: 'Job Name'),
            const SizedBox(height: 12),
            _Field(controller: locCtrl, label: 'Location'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.outline, fontSize: 12)),
          ),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final p = ctx.read<AppProvider>();
              final job =
                  await p.createJob(nameCtrl.text.trim(), locCtrl.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => JobDetailScreen(job: job)),
                );
              }
            },
            child: const Text('CREATE',
                style: TextStyle(
                    color: AppColors.primaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onOpenAccount: onOpenAccount),
            Expanded(
              child: Consumer<AppProvider>(
                builder: (_, p, __) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  children: [
                    // Flagged banner — only when there are flagged photos
                    Builder(builder: (ctx) {
                      final totalFlagged = p.jobs.fold<int>(0, (sum, j) =>
                          sum + j.inspections.fold<int>(0, (s2, i) =>
                              s2 + i.photos.where((ph) => ph.isFlagged).length));
                      if (totalFlagged == 0) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () => Navigator.push(ctx,
                            MaterialPageRoute(builder: (_) => const FlaggedScreen())),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.onTertiaryContainer.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.onTertiaryContainer.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.errorContainer.withOpacity(0.3),
                                  blurRadius: 12),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.flag,
                                  color: AppColors.onTertiaryContainer, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$totalFlagged item${totalFlagged == 1 ? '' : 's'} flagged for follow-up',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onTertiaryContainer),
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.onTertiaryContainer, size: 18),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (p.activeJobs.isNotEmpty) ...[
                      _SectionLabel('ACTIVE'),
                      ...p.activeJobs
                          .map((j) => _JobCard(job: j, completed: false)),
                      const SizedBox(height: 16),
                    ],
                    if (p.completedJobs.isNotEmpty) ...[
                      _SectionLabel('COMPLETED'),
                      ...p.completedJobs
                          .map((j) => _JobCard(job: j, completed: true)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SizedBox(
          width: MediaQuery.of(context).size.width - 40,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _newInspection(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 8,
              shadowColor: AppColors.primaryContainer.withOpacity(0.4),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('NEW SITE',
                style:
                    TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8, fontSize: 13)),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback? onOpenAccount;
  const _Header({this.onOpenAccount});
  @override
  Widget build(BuildContext context) {
    final month =
        DateFormat('MMM yyyy').format(DateTime.now()).toUpperCase();
    return Consumer<AppProvider>(
      builder: (_, p, __) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Site Memo',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface)),
                Text(
                  '${p.jobs.length} JOBS • $month',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5),
                ),
              ],
            ),
            GestureDetector(
              onTap: onOpenAccount,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.surfaceContainerHigh,
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Icon(Icons.person,
                    color: AppColors.outline, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.outline,
              letterSpacing: 0.6)),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Job job;
  final bool completed;
  const _JobCard({required this.job, required this.completed});

  String _dateLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }

  void _showEditDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: job.name);
    final locCtrl = TextEditingController(text: job.location);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Job',
            style: TextStyle(
                color: AppColors.onSurface, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Field(controller: nameCtrl, label: 'Job Name'),
            const SizedBox(height: 12),
            _Field(controller: locCtrl, label: 'Location'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.outline, fontSize: 12)),
          ),
          TextButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await ctx.read<AppProvider>().editJob(
                    job.id,
                    nameCtrl.text.trim(),
                    locCtrl.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('SAVE',
                style: TextStyle(
                    color: AppColors.primaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Job',
            style: TextStyle(
                color: AppColors.onSurface, fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${job.name}"? This removes all ${job.inspectionCount} inspection${job.inspectionCount == 1 ? '' : 's'} and cannot be undone.',
          style: const TextStyle(
              color: AppColors.onSurfaceVariant, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.outline, fontSize: 12)),
          ),
          TextButton(
            onPressed: () async {
              await ctx.read<AppProvider>().deleteJob(job.id);
              if (ctx.mounted) Navigator.pop(ctx);
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
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: completed ? 0.55 : 1.0,
        child: GlassCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completed ? AppColors.outline : AppColors.primary,
                    boxShadow: completed
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.6),
                              blurRadius: 8,
                            )
                          ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface)),
                    const SizedBox(height: 2),
                    Text(job.location,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onSurfaceVariant)),
                    if (!completed) ...[
                      const SizedBox(height: 10),
                      _StatusChip(label: 'IN PROGRESS'),
                    ],
                  ],
                ),
              ),
              // Right side: photo count + date + menu
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${job.inspectionCount} inspection${job.inspectionCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Text(_dateLabel(job.updatedAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.outline)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: const Icon(Icons.more_vert,
                          color: AppColors.outline, size: 18),
                      color: AppColors.surfaceContainerHigh,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      onSelected: (v) {
                        if (v == 'edit') _showEditDialog(context);
                        if (v == 'delete') _showDeleteDialog(context);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: const [
                              Icon(Icons.edit_outlined,
                                  color: AppColors.primary, size: 16),
                              SizedBox(width: 10),
                              Text('Edit',
                                  style: TextStyle(
                                      color: AppColors.onSurface,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: const [
                              Icon(Icons.delete_outline,
                                  color: AppColors.error, size: 16),
                              SizedBox(width: 10),
                              Text('Delete',
                                  style: TextStyle(
                                      color: AppColors.error, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  final int count;
  const _IssueChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.onTertiaryContainer.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: AppColors.onTertiaryContainer.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: AppColors.errorContainer.withOpacity(0.35),
              blurRadius: 10)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag, color: AppColors.onTertiaryContainer, size: 12),
          const SizedBox(width: 4),
          Text('$count ISSUES',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onTertiaryContainer)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.4)),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _Field({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.onSurface),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.outline, fontSize: 13),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.outlineVariant)),
        focusedBorder: const UnderlineInputBorder(
            borderSide:
                BorderSide(color: AppColors.primaryContainer, width: 2)),
      ),
    );
  }
}
