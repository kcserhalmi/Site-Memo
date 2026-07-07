import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../providers/app_provider.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/press_scale.dart';
import 'flagged_screen.dart';
import 'job_detail_screen.dart';
import 'paywall_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenAccount;
  const DashboardScreen({super.key, this.onOpenAccount});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _continueDismissed = false;

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
            _Header(onOpenAccount: widget.onOpenAccount),
            Expanded(
              child: Consumer<AppProvider>(
                builder: (_, p, __) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  children: [
                    // Trial banner — hidden for Pro users and in demo mode
                    Builder(builder: (ctx) {
                      final sub = SubscriptionService.current;
                      if (p.isDemoMode || sub.isPro || !sub.isTrialActive) {
                        return const SizedBox.shrink();
                      }
                      return PressScale(
                        pressedScale: 0.97,
                        onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                                builder: (_) => const PaywallScreen())),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryContainer.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.primaryContainer
                                    .withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.workspace_premium_outlined,
                                  color: AppColors.primary, size: 16),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Free trial — ${sub.trialDaysLeft} day${sub.trialDaysLeft == 1 ? '' : 's'} left',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary),
                                ),
                              ),
                              const Text('See plans',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryFixedDim)),
                              const Icon(Icons.chevron_right,
                                  color: AppColors.primaryFixedDim, size: 16),
                            ],
                          ),
                        ),
                      );
                    }),
                    // Continue last inspection card
                    if (!_continueDismissed) Builder(builder: (ctx) {
                      // Find most recent inspection from today with photos
                      final today = DateTime.now();
                      for (final job in p.activeJobs) {
                        for (final insp in [...job.inspections]
                            ..sort((a, b) => b.date.compareTo(a.date))) {
                          final sameDay = insp.date.year == today.year &&
                              insp.date.month == today.month &&
                              insp.date.day == today.day;
                          if (sameDay && insp.photos.isNotEmpty) {
                            return _ContinueCard(
                              siteName: job.name,
                              inspectionTitle: insp.title,
                              photoCount: insp.photoCount,
                              onContinue: () => Navigator.push(ctx,
                                  MaterialPageRoute(
                                      builder: (_) => JobDetailScreen(job: job))),
                              onDismiss: () =>
                                  setState(() => _continueDismissed = true),
                            );
                          }
                        }
                      }
                      return const SizedBox.shrink();
                    }),
                    // Flagged banner — only when there are flagged photos
                    Builder(builder: (ctx) {
                      final totalFlagged = p.totalFlaggedCount;
                      if (totalFlagged == 0) return const SizedBox.shrink();
                      return PressScale(
                        pressedScale: 0.97,
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
                    if (p.jobs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 100),
                        child: Column(
                          children: [
                            const Icon(Icons.add_business_outlined,
                                color: AppColors.outline, size: 56),
                            const SizedBox(height: 16),
                            const Text('No job sites yet',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            Text(
                              'Create a site below, then start\ncapturing photos from the Camera tab.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.outline.withOpacity(0.8),
                                  height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    if (p.activeJobs.isNotEmpty) ...[
                      _SectionLabel('Active'),
                      ...p.activeJobs
                          .map((j) => _JobCard(job: j, completed: false)),
                      const SizedBox(height: 16),
                    ],
                    if (p.completedJobs.isNotEmpty) ...[
                      _SectionLabel('Completed'),
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
                  borderRadius: BorderRadius.circular(14)),
              elevation: 8,
              shadowColor: AppColors.primaryContainer.withOpacity(0.4),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('New site',
                style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2, fontSize: 13)),
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
    final month = DateFormat('MMM yyyy').format(DateTime.now());
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
                  '${p.activeJobs.length} active · ${p.totalPhotoCount} photos · $month',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.1),
                ),
              ],
            ),
            PressScale(
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
      child: Row(
        children: [
          Text(text,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.outline,
                  letterSpacing: 0.2)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 0.5,
              color: AppColors.outlineVariant,
            ),
          ),
        ],
      ),
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
                      const SizedBox(height: 6),
                      const Text('in progress',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500)),
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

class _ContinueCard extends StatefulWidget {
  final String siteName;
  final String inspectionTitle;
  final int photoCount;
  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  const _ContinueCard({
    required this.siteName,
    required this.inspectionTitle,
    required this.photoCount,
    required this.onContinue,
    required this.onDismiss,
  });

  @override
  State<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<_ContinueCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 130),
      curve: const Cubic(0.23, 1.0, 0.32, 1.0),
      child: Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: AppColors.primaryFixedDim.withOpacity(0.7), width: 3),
          top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.25)),
          right: BorderSide(color: AppColors.outlineVariant.withOpacity(0.25)),
          bottom: BorderSide(color: AppColors.outlineVariant.withOpacity(0.25)),
        ),
      ),
      child: Row(
        children: [
          // Tap area
          Expanded(
            child: GestureDetector(
              onTap: widget.onContinue,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.play_arrow,
                          color: AppColors.primaryFixedDim, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CONTINUE TODAY',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryFixedDim,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(widget.inspectionTitle,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text('${widget.siteName}  ·  ${widget.photoCount} photos',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.outline, size: 18),
                  ],
                ),
              ),
            ),
          ),
          // Dismiss button
          GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(Icons.close,
                  color: AppColors.outline.withOpacity(0.6), size: 16),
            ),
          ),
        ],
      ),
      ), // AnimatedScale
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
