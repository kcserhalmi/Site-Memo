import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inspection.dart';
import '../models/inspection_photo.dart';
import '../models/job.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/glass_card.dart';
import 'photo_detail_screen.dart';

class FlaggedScreen extends StatelessWidget {
  const FlaggedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Gather all flagged photos with their parent context
    final items = <_FlaggedItem>[];
    for (final job in provider.jobs) {
      for (final insp in job.inspections) {
        for (int i = 0; i < insp.photos.length; i++) {
          if (insp.photos[i].isFlagged) {
            items.add(_FlaggedItem(
              job: job,
              inspection: insp,
              photo: insp.photos[i],
              photoIndex: i + 1,
            ));
          }
        }
      }
    }

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
            const Text('Flagged Items',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface)),
            Text('${items.length} photo${items.length == 1 ? '' : 's'} need attention',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
      body: items.isEmpty
          ? const _EmptyFlagged()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: items.length,
              itemBuilder: (_, i) => _FlaggedCard(item: items[i]),
            ),
    );
  }
}

class _FlaggedItem {
  final Job job;
  final Inspection inspection;
  final InspectionPhoto photo;
  final int photoIndex;
  const _FlaggedItem(
      {required this.job,
      required this.inspection,
      required this.photo,
      required this.photoIndex});
}

class _FlaggedCard extends StatelessWidget {
  final _FlaggedItem item;
  const _FlaggedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PhotoDetailScreen(
                    photo: item.photo,
                    photoIndex: item.photoIndex,
                  )),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: appImage(
                  item.photo.imagePath,
                  fit: BoxFit.cover,
                  fallback: Container(color: AppColors.surfaceContainerHigh),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parent context
                  Row(
                    children: [
                      const Icon(Icons.business_outlined,
                          size: 11, color: AppColors.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${item.job.name}  ›  ${item.inspection.title}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.outline,
                              letterSpacing: 0.1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Location tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(item.photo.category,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.3)),
                  ),
                  const SizedBox(height: 6),
                  // Transcription preview or date
                  if (item.photo.transcription != null &&
                      item.photo.transcription!.isNotEmpty)
                    Text(
                      item.photo.transcription!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      item.inspection.dateLabel,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.outline),
                    ),
                ],
              ),
            ),
            // Unflag button
            GestureDetector(
              onTap: () => context.read<AppProvider>().toggleFlag(
                    item.photo.jobId,
                    item.photo.inspectionId,
                    item.photo.id,
                  ),
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.onTertiaryContainer.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.onTertiaryContainer.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.flag,
                      color: AppColors.onTertiaryContainer, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFlagged extends StatelessWidget {
  const _EmptyFlagged();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag_outlined, color: AppColors.outline, size: 52),
            SizedBox(height: 16),
            Text('No flagged items',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant)),
            SizedBox(height: 8),
            Text('Flag photos that need follow-up\nfrom any Photo Detail screen.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.outline)),
          ],
        ),
      );
}
