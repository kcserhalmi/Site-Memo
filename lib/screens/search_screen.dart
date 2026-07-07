import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inspection_photo.dart';
import '../models/job.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/file_utils.dart';
import '../widgets/glass_card.dart';
import 'photo_detail_screen.dart';
import 'job_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final jobs = _filterJobs(provider.jobs);
    final photos = _filterPhotos(provider.jobs);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Search',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(
                          color: AppColors.onSurface, fontSize: 15),
                      cursorColor: AppColors.primary,
                      onChanged: (v) => setState(() => _query = v.toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: 'Search jobs, locations, notes…',
                        hintStyle: TextStyle(
                            color: AppColors.outline, fontSize: 14),
                        prefixIcon:
                            Icon(Icons.search, color: AppColors.outline),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.isEmpty
                  ? _EmptySearch()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      children: [
                        if (jobs.isNotEmpty) ...[
                          _SectionHeader('JOBS (${jobs.length})'),
                          ...jobs.map((j) => _JobResult(job: j)),
                          const SizedBox(height: 16),
                        ],
                        if (photos.isNotEmpty) ...[
                          _SectionHeader('PHOTOS (${photos.length})'),
                          ...photos.map((r) => _PhotoResult(
                              photo: r.$1, index: r.$2,
                              siteName: r.$3, inspectionTitle: r.$4)),
                        ],
                        if (jobs.isEmpty && photos.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 48),
                            child: Center(
                              child: Text('No results found',
                                  style: TextStyle(
                                      color: AppColors.outline, fontSize: 14)),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Job> _filterJobs(List<Job> jobs) {
    if (_query.isEmpty) return [];
    return jobs.where((j) {
      return j.name.toLowerCase().contains(_query) ||
          j.location.toLowerCase().contains(_query);
    }).toList();
  }

  // Returns (photo, photoIndex, siteName, inspectionTitle)
  List<(InspectionPhoto, int, String, String)> _filterPhotos(List<Job> jobs) {
    if (_query.isEmpty) return [];
    final results = <(InspectionPhoto, int, String, String)>[];
    for (final job in jobs) {
      for (final insp in job.inspections) {
        for (int i = 0; i < insp.photos.length; i++) {
          final p = insp.photos[i];
          if ((p.transcription?.toLowerCase().contains(_query) ?? false) ||
              (p.caption?.toLowerCase().contains(_query) ?? false) ||
              p.category.toLowerCase().contains(_query) ||
              insp.title.toLowerCase().contains(_query) ||
              insp.notes.toLowerCase().contains(_query) ||
              job.name.toLowerCase().contains(_query)) {
            results.add((p, i + 1, job.name, insp.title));
          }
        }
      }
    }
    return results;
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.outline,
              letterSpacing: 0.5)),
    );
  }
}

class _JobResult extends StatelessWidget {
  final Job job;
  const _JobResult({required this.job});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
        ),
        child: Row(
          children: [
            const Icon(Icons.work_outline,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                  Text(job.location,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Text('${job.photoCount} photos',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.outline)),
          ],
        ),
      ),
    );
  }
}

class _PhotoResult extends StatelessWidget {
  final InspectionPhoto photo;
  final int index;
  final String siteName;
  final String inspectionTitle;
  const _PhotoResult(
      {required this.photo,
      required this.index,
      required this.siteName,
      required this.inspectionTitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  PhotoDetailScreen(photos: [photo], initialIndex: 0)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 56,
                child: photo.imagePath.isNotEmpty
                    ? appImage(photo.imagePath, fit: BoxFit.cover,
                        networkUrl: photo.storageUrl,
                        fallback: Container(
                            color: AppColors.surfaceContainerHigh,
                            child: const Icon(Icons.image,
                                color: AppColors.outline)))
                    : Container(
                        color: AppColors.surfaceContainerHigh,
                        child: const Icon(Icons.image,
                            color: AppColors.outline)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Parent context — site › inspection
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 10, color: AppColors.outline),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '$siteName  ›  $inspectionTitle',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.outline,
                              letterSpacing: 0.1),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Location tag
                  Text(photo.category,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.3)),
                  if (photo.transcription != null &&
                      photo.transcription!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      photo.transcription!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (photo.isFlagged)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.flag,
                    color: AppColors.onTertiaryContainer, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, color: AppColors.outline, size: 52),
          SizedBox(height: 16),
          Text('Search jobs & notes',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant)),
          SizedBox(height: 8),
          Text('Find by job name, location,\nor voice note transcription',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: AppColors.outline)),
        ],
      ),
    );
  }
}
