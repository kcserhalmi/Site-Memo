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

// ─────────────────────────────────────────────────────────────────────────────
// Outer widget — owns navigation, app bar, and PageView
// ─────────────────────────────────────────────────────────────────────────────

class PhotoDetailScreen extends StatefulWidget {
  final List<InspectionPhoto> photos;
  final int initialIndex;

  const PhotoDetailScreen({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<PhotoDetailScreen> createState() => _PhotoDetailScreenState();
}

class _PhotoDetailScreenState extends State<PhotoDetailScreen> {
  late PageController _pageCtrl;
  late int _currentIdx;

  InspectionPhoto get _photo => widget.photos[_currentIdx];

  @override
  void initState() {
    super.initState();
    _currentIdx = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── App-bar actions ────────────────────────────────────────────────────────

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
              final p = _photo;
              await context
                  .read<AppProvider>()
                  .deletePhoto(p.jobId, p.inspectionId, p.id);
              if (dCtx.mounted) Navigator.pop(dCtx);
              if (context.mounted) {
                if (widget.photos.length == 1) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    widget.photos.remove(p);
                    if (_currentIdx >= widget.photos.length) {
                      _currentIdx = widget.photos.length - 1;
                    }
                  });
                }
              }
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
    final p = _photo;
    try {
      final text = p.caption != null && p.caption!.isNotEmpty
          ? p.caption!
          : (p.transcription != null && p.transcription!.isNotEmpty
              ? '${p.category} — ${p.transcription}'
              : p.category);
      await Share.shareXFiles([XFile(p.imagePath)],
          text: text, subject: 'Site Memo – ${p.category}');
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
    final p = _photo;
    context.read<AppProvider>().toggleFlag(p.jobId, p.inspectionId, p.id);
    setState(() {});
  }

  Future<void> _openAnnotation() async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoAnnotationScreen(
          imagePath: _photo.imagePath,
          photoId: _photo.id,
          jobId: _photo.jobId,
          inspectionId: _photo.inspectionId,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  void _editTranscription() {
    final p = _photo;
    final ctrl = TextEditingController(text: p.transcription ?? '');
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Transcription',
            style: TextStyle(
                color: AppColors.onSurface, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          style: const TextStyle(
              color: AppColors.onSurface, fontSize: 14, height: 1.5),
          cursorColor: AppColors.primary,
          decoration: const InputDecoration(
            hintText: 'Type or correct transcription…',
            hintStyle: TextStyle(color: AppColors.outline, fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.outline, fontSize: 12)),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().updatePhotoVoiceNote(
                    p.jobId, p.inspectionId, p.id,
                    p.voiceNotePath,
                    ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : null);
              if (dCtx.mounted) Navigator.pop(dCtx);
              if (mounted) setState(() {});
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isFlagged = _photo.isFlagged;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(children: [
                      Icon(Icons.arrow_back, color: AppColors.onSurface),
                      SizedBox(width: 6),
                      Text('Back',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface)),
                    ]),
                  ),
                  const Spacer(),
                  // Delete
                  _HeaderBtn(
                    onTap: () => _confirmDelete(context),
                    child: const Icon(Icons.delete_outline,
                        color: AppColors.error, size: 16),
                    borderColor: AppColors.error.withOpacity(0.3),
                  ),
                  const SizedBox(width: 6),
                  // Annotate
                  _HeaderBtn(
                    onTap: _openAnnotation,
                    label: 'ANNOTATE',
                    icon: Icons.draw_outlined,
                    borderColor: AppColors.outline.withOpacity(0.3),
                    color: AppColors.outline,
                  ),
                  const SizedBox(width: 6),
                  // Flag
                  _HeaderBtn(
                    onTap: _toggleFlag,
                    label: isFlagged ? 'FLAGGED' : 'FLAG',
                    icon: isFlagged ? Icons.flag : Icons.flag_outlined,
                    borderColor: isFlagged
                        ? AppColors.onTertiaryContainer
                        : AppColors.outline.withOpacity(0.3),
                    color: isFlagged
                        ? AppColors.onTertiaryContainer
                        : AppColors.outline,
                    filled: isFlagged,
                  ),
                  const SizedBox(width: 6),
                  // Share
                  _HeaderBtn(
                    onTap: _share,
                    label: 'SHARE',
                    borderColor: AppColors.primary.withOpacity(0.3),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            // Page indicator (when multiple photos)
            if (widget.photos.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${_currentIdx + 1} / ${widget.photos.length}',
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.outline,
                      letterSpacing: 0.3),
                ),
              ),
            // Photo pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentIdx = i),
                itemCount: widget.photos.length,
                itemBuilder: (_, i) => _PhotoPage(
                  key: ValueKey(widget.photos[i].id),
                  photo: widget.photos[i],
                  photoIndex: i + 1,
                  onEditTranscription: _editTranscription,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-photo page — owns playback and recording state
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoPage extends StatefulWidget {
  final InspectionPhoto photo;
  final int photoIndex;
  final VoidCallback onEditTranscription;

  const _PhotoPage({
    super.key,
    required this.photo,
    required this.photoIndex,
    required this.onEditTranscription,
  });

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Lazy — only created when user taps the mic
  AudioRecorder? _recorder;
  SpeechToText? _speech;
  bool _speechAvail = false;
  bool _isRecording = false;
  String _liveTranscription = '';

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged
        .listen((p) => setState(() => _position = p));
    _player.onDurationChanged
        .listen((d) => setState(() => _duration = d));
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _ensureRecorder() async {
    _recorder ??= AudioRecorder();
    if (_speech == null) {
      _speech = SpeechToText();
      try {
        _speechAvail = await _speech!.initialize(
            onError: (_) {}, onStatus: (_) {});
      } catch (_) {}
    }
  }

  Future<void> _togglePlay() async {
    if (widget.photo.voiceNotePath == null) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.play(DeviceFileSource(widget.photo.voiceNotePath!));
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      final path = await _recorder!.stop();
      try { await _speech!.stop(); } catch (_) {}
      setState(() => _isRecording = false);
      if (path != null && mounted) {
        final p = widget.photo;
        await context.read<AppProvider>().updatePhotoVoiceNote(
            p.jobId, p.inspectionId, p.id, path,
            _liveTranscription.isNotEmpty ? _liveTranscription : null);
        setState(() {});
      }
    } else {
      await _ensureRecorder();
      final hasPermission = await _recorder!.hasPermission();
      if (!hasPermission) return;
      final recordPath = kIsWeb
          ? 'voice_${DateTime.now().millisecondsSinceEpoch}.webm'
          : '${(await getApplicationDocumentsDirectory()).path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      try {
        await _recorder!.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: recordPath);
      } catch (_) {
        return;
      }
      if (_speechAvail) {
        try {
          await _speech!.listen(
            onResult: (r) =>
                setState(() => _liveTranscription = r.recognizedWords),
            listenOptions: SpeechListenOptions(
                cancelOnError: false, partialResults: true),
          );
        } catch (_) {}
      }
      setState(() {
        _isRecording = true;
        _liveTranscription = '';
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _recorder?.dispose();
    try { _speech?.cancel(); } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Column(
        children: [
          _buildHero(photo),
          const SizedBox(height: 16),
          _buildVoiceCard(photo),
          const SizedBox(height: 14),
          _buildMetaGrid(photo),
          const SizedBox(height: 12),
          _buildLocationCard(photo),
        ],
      ),
    );
  }

  Widget _buildHero(InspectionPhoto photo) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            appImage(photo.imagePath,
                fallback: Container(
                  color: AppColors.surfaceContainerHigh,
                  child: const Icon(Icons.image,
                      size: 64, color: AppColors.outline),
                )),
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
              child: Row(children: [
                _TagBadge(
                  label: photo.category,
                  color: photo.category == 'DAMAGE'
                      ? AppColors.onTertiaryContainer
                      : AppColors.primary,
                  filled: true,
                ),
                if (photo.isFlagged) ...[
                  const SizedBox(width: 6),
                  _TagBadge(
                      label: 'FLAGGED',
                      color: AppColors.onTertiaryContainer,
                      filled: true),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceCard(InspectionPhoto photo) {
    final hasNote = photo.voiceNotePath != null || photo.transcription != null;

    // No note, not recording → show add button
    if (!hasNote && !_isRecording) {
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
                GestureDetector(
                  onTap: widget.onEditTranscription,
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_outlined, color: AppColors.outline, size: 13),
                    SizedBox(width: 4),
                    Text('EDIT',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.outline)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _toggleRecord,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.outlineVariant.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.mic_outlined,
                        color: AppColors.outline, size: 18),
                    SizedBox(width: 8),
                    Text('TAP TO ADD VOICE NOTE',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.outline,
                            letterSpacing: 0.4)),
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
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.outline,
                        letterSpacing: 0.5)),
                GestureDetector(
                  onTap: _toggleRecord,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.4)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.stop, color: AppColors.error, size: 14),
                      SizedBox(width: 4),
                      Text('STOP',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            WaveformVisualizer(isActive: true, barCount: 18, height: 26),
            if (_liveTranscription.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_liveTranscription,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurface,
                      fontStyle: FontStyle.italic,
                      height: 1.5)),
            ],
          ],
        ),
      );
    }

    // Has note — show playback + transcription
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds)
            .clamp(0.0, 1.0)
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
              GestureDetector(
                onTap: widget.onEditTranscription,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_outlined,
                      color: AppColors.outline, size: 13),
                  SizedBox(width: 4),
                  Text('EDIT',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.outline)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (photo.caption != null && photo.caption!.isNotEmpty) ...[
            Text(photo.caption!,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface)),
            const SizedBox(height: 8),
          ],
          if (photo.transcription != null && photo.transcription!.isNotEmpty)
            Text(photo.transcription!,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface,
                    height: 1.5)),
          if (photo.voiceNotePath != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainerHigh,
                  ),
                  child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppColors.primary,
                      size: 18),
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
              Text(_fmtDur(_position),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.outline)),
            ]),
            const SizedBox(height: 6),
            WaveformVisualizer(
                isActive: _isPlaying,
                barCount: 20,
                height: 24,
                color: AppColors.primaryFixedDim.withOpacity(0.6)),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaGrid(InspectionPhoto photo) {
    final dt = photo.timestamp;
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final time = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    final date = '${m[dt.month-1]} ${dt.day}';
    return Row(children: [
      _MetaBox(label: 'TIME', value: time),
      const SizedBox(width: 8),
      _MetaBox(label: 'DATE', value: date),
      const SizedBox(width: 8),
      _MetaBox(label: 'PHOTO', value: '#${widget.photoIndex}'),
    ]);
  }

  Widget _buildLocationCard(InspectionPhoto photo) {
    return GlassCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ]),
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final Widget? child;
  final Color borderColor;
  final Color? color;
  final bool filled;

  const _HeaderBtn({
    required this.onTap,
    this.label,
    this.icon,
    this.child,
    required this.borderColor,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: label != null ? 8 : 8, vertical: 6),
          decoration: BoxDecoration(
            color: filled ? (color ?? AppColors.outline).withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: child ??
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null)
                    Icon(icon, color: color ?? AppColors.outline, size: 13),
                  if (icon != null && label != null) const SizedBox(width: 4),
                  if (label != null)
                    Text(label!,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color ?? AppColors.outline,
                            letterSpacing: 0.3)),
                ],
              ),
        ),
      );
}

class _TagBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  const _TagBadge(
      {required this.label, required this.color, this.filled = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: filled ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.flag, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.3)),
        ]),
      );
}

class _MetaBox extends StatelessWidget {
  final String label;
  final String value;
  const _MetaBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Expanded(
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          borderRadius: BorderRadius.circular(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          ]),
        ),
      );
}
