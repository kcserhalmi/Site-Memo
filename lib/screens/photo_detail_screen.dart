import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../utils/file_utils.dart';
import 'package:flutter/material.dart';
import '../models/inspection_photo.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/waveform_visualizer.dart';
import 'photo_annotation_screen.dart';

class PhotoDetailScreen extends StatefulWidget {
  final InspectionPhoto photo;
  final int photoIndex;
  final String? jobId;

  const PhotoDetailScreen({
    super.key,
    required this.photo,
    required this.photoIndex,
    this.jobId,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  // Playback
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Recording (for photos that don't have a voice note yet)
  final _recorder = AudioRecorder();
  final _speech = SpeechToText();
  bool _speechAvail = false;
  bool _isRecording = false;
  String _liveTranscription = '';
  String? _newAudioPath;

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged
        .listen((p) => setState(() => _position = p));
    _player.onDurationChanged
        .listen((d) => setState(() => _duration = d));
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _position = Duration.zero; });
    });
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvail = await _speech.initialize(onError: (_) {}, onStatus: (_) {});
    } catch (_) {}
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      _newAudioPath = await _recorder.stop();
      try { await _speech.stop(); } catch (_) {}
      setState(() => _isRecording = false);
      // Save to photo
      if (_newAudioPath != null) {
        final p = widget.photo;
        await context.read<AppProvider>().updatePhotoVoiceNote(
            p.jobId, p.inspectionId, p.id,
            _newAudioPath, _liveTranscription.isNotEmpty ? _liveTranscription : null);
        setState(() {});
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return;
      final path = kIsWeb
          ? 'voice_${DateTime.now().millisecondsSinceEpoch}.webm'
          : '${(await getApplicationDocumentsDirectory()).path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      try {
        await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      } catch (_) { return; }
      if (_speechAvail) {
        try {
          await _speech.listen(
            onResult: (r) => setState(() => _liveTranscription = r.recognizedWords),
            listenOptions: SpeechListenOptions(cancelOnError: false, partialResults: true),
          );
        } catch (_) {}
      }
      setState(() { _isRecording = true; _liveTranscription = ''; });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _recorder.dispose();
    try { _speech.cancel(); } catch (_) {}
    super.dispose();
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Photo?',
            style: TextStyle(
                color: AppColors.onSurface, fontWeight: FontWeight.w700)),
        content: const Text(
            'This photo and its voice note will be permanently removed.',
            style: TextStyle(
                color: AppColors.onSurfaceVariant, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.outline, fontSize: 12)),
          ),
          TextButton(
            onPressed: () async {
              final p = widget.photo;
              await context
                  .read<AppProvider>()
                  .deletePhoto(p.jobId, p.inspectionId, p.id);
              if (dCtx.mounted) Navigator.pop(dCtx);
              if (context.mounted) Navigator.pop(context);
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

  Future<void> _share() async {
    final photo = widget.photo;
    try {
      final text = photo.transcription != null && photo.transcription!.isNotEmpty
          ? '${photo.category} — ${photo.transcription}'
          : photo.category;
      await Share.shareXFiles(
        [XFile(photo.imagePath)],
        text: text,
        subject: 'Site Memo – ${photo.category}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Share failed: $e'),
          backgroundColor: AppColors.surfaceContainerHigh,
        ));
      }
    }
  }

  void _toggleFlag() {
    final p = widget.photo;
    context.read<AppProvider>().toggleFlag(
        p.jobId, p.inspectionId, p.id);
    setState(() {});
  }

  Future<void> _openAnnotation() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoAnnotationScreen(
          imagePath: widget.photo.imagePath,
          photoId: widget.photo.id,
          jobId: widget.photo.jobId,
          inspectionId: widget.photo.inspectionId,
        ),
      ),
    );
    if (result != null && mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    if (widget.photo.voiceNotePath == null) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      final src = DeviceFileSource(widget.photo.voiceNotePath!);
      await _player.play(src);
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back, color: AppColors.onSurface),
                        SizedBox(width: 6),
                        Text('Back',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Delete
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: AppColors.error, size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Annotate
                  GestureDetector(
                    onTap: _openAnnotation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.outline.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.draw_outlined,
                              color: AppColors.outline, size: 14),
                          SizedBox(width: 4),
                          Text('ANNOTATE',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.outline,
                                  letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Flag
                  GestureDetector(
                    onTap: _toggleFlag,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: widget.photo.isFlagged
                            ? AppColors.onTertiaryContainer.withOpacity(0.15)
                            : Colors.transparent,
                        border: Border.all(
                            color: widget.photo.isFlagged
                                ? AppColors.onTertiaryContainer
                                : AppColors.outline.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.photo.isFlagged
                                ? Icons.flag
                                : Icons.flag_outlined,
                            color: widget.photo.isFlagged
                                ? AppColors.onTertiaryContainer
                                : AppColors.outline,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.photo.isFlagged ? 'FLAGGED' : 'FLAG',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: widget.photo.isFlagged
                                    ? AppColors.onTertiaryContainer
                                    : AppColors.outline,
                                letterSpacing: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Share
                  GestureDetector(
                    onTap: _share,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: const Text('SHARE',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 0.3)),
                    ),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: [
                    // Hero photo
                    _buildPhotoHero(photo),
                    const SizedBox(height: 20),
                    // Voice note (always shown)
                    _buildVoiceCard(photo),
                    const SizedBox(height: 16),
                    // Metadata grid
                    _buildMetaGrid(photo),
                    const SizedBox(height: 12),
                    // Category
                    _buildCategoryRow(photo),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoHero(InspectionPhoto photo) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            appImage(
              photo.imagePath,
              fallback: Container(
                color: AppColors.surfaceContainerHigh,
                child: const Icon(Icons.image, size: 64, color: AppColors.outline),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x99000000)],
                  stops: [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Row(
                children: [
                  _TagBadge(
                    label: photo.category,
                    color: photo.category == 'DAMAGE'
                        ? AppColors.onTertiaryContainer
                        : AppColors.primary,
                    filled: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceCard(InspectionPhoto photo) {
    // No note yet — show record button
    final hasNote = photo.voiceNotePath != null || photo.transcription != null;
    if (!hasNote && !_isRecording) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('VOICE NOTE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.outline, letterSpacing: 0.5)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _toggleRecord,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_outlined, color: AppColors.outline, size: 18),
                    SizedBox(width: 8),
                    Text('TAP TO ADD VOICE NOTE',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.outline, letterSpacing: 0.4)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Recording in progress
    if (_isRecording) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('VOICE NOTE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.outline, letterSpacing: 0.5)),
                GestureDetector(
                  onTap: _toggleRecord,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: AppColors.error.withOpacity(0.4)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.stop, color: AppColors.error, size: 14),
                      SizedBox(width: 5),
                      Text('STOP', style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w700, color: AppColors.error)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            WaveformVisualizer(isActive: true, barCount: 18, height: 28),
            if (_liveTranscription.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_liveTranscription,
                  style: const TextStyle(fontSize: 13, color: AppColors.onSurface,
                      fontStyle: FontStyle.italic, height: 1.5)),
            ],
          ],
        ),
      );
    }

    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('VOICE NOTE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.outline,
                      letterSpacing: 0.5)),
              Icon(Icons.graphic_eq,
                  color: AppColors.outline.withOpacity(0.6), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          if (photo.transcription != null && photo.transcription!.isNotEmpty)
            Text(photo.transcription!,
                style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.onSurface,
                    height: 1.5)),
          if (photo.voiceNotePath != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainerHigh,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.surfaceContainerHighest,
                      valueColor: const AlwaysStoppedAnimation(
                          AppColors.primaryFixedDim),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_fmtDur(_position)} / ${_fmtDur(_duration)}',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            WaveformVisualizer(
              isActive: _isPlaying,
              barCount: 20,
              height: 28,
              color: AppColors.primaryFixedDim.withOpacity(0.7),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaGrid(InspectionPhoto photo) {
    final dt = photo.timestamp;
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    final time = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    final date = '${months[dt.month-1]} ${dt.day}';

    return Row(
      children: [
        _MetaBox(label: 'TIME', value: time),
        const SizedBox(width: 8),
        _MetaBox(label: 'DATE', value: date),
        const SizedBox(width: 8),
        _MetaBox(label: 'PHOTO', value: '#${widget.photoIndex}'),
      ],
    );
  }

  Widget _buildCategoryRow(InspectionPhoto photo) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('LOCATION',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.outline,
                      letterSpacing: 0.4)),
              const SizedBox(height: 4),
              Text(photo.category,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface)),
            ],
          ),
          const Icon(Icons.chevron_right, color: AppColors.primary),
        ],
      ),
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _TagBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _TagBadge(
      {required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3)),
        ],
      ),
    );
  }
}

class _MetaBox extends StatelessWidget {
  final String label;
  final String value;
  const _MetaBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.outline,
                    letterSpacing: 0.4)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface)),
          ],
        ),
      ),
    );
  }
}
