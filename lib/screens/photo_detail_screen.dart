import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:share_plus/share_plus.dart';
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
              // Always pop back — let parent screen handle the updated list
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
                  onFullScreen: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FullPhotoScreen(
                      photos: widget.photos,
                      initialIndex: i,
                    ),
                  )),
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
  final VoidCallback onFullScreen;

  const _PhotoPage({
    super.key,
    required this.photo,
    required this.photoIndex,
    required this.onEditTranscription,
    required this.onFullScreen,
  });

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> {
  // Speech-to-text for notes (no audio recording)
  final _speech = SpeechToText();
  bool _speechAvail = false;
  bool _isListening = false;
  final _notesCtrl = TextEditingController();
  bool _editingNotes = false; // true when inline notes editor is open

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final avail = await _speech.initialize(onError: (_) {}, onStatus: (_) {});
        if (mounted) setState(() => _speechAvail = avail);
      } catch (_) {}
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      try { await _speech.stop(); } catch (_) {}
      setState(() => _isListening = false);
    } else if (_speechAvail) {
      try {
        await _speech.listen(
          onResult: (r) {
            if (mounted && r.recognizedWords.isNotEmpty) {
              setState(() => _notesCtrl.text = r.recognizedWords);
            }
          },
          listenOptions: SpeechListenOptions(cancelOnError: false, partialResults: true),
        );
        setState(() => _isListening = true);
      } catch (_) {}
    }
  }

  Future<void> _saveNotes() async {
    final text = _notesCtrl.text.trim();
    if (!mounted) return;
    final p = widget.photo;
    await context.read<AppProvider>().updatePhotoVoiceNote(
        p.jobId, p.inspectionId, p.id, null,
        text.isNotEmpty ? text : null);
    setState(() { _editingNotes = false; _isListening = false; });
    try { await _speech.stop(); } catch (_) {}
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    try { _speech.cancel(); } catch (_) {}
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
    return GestureDetector(
      onTap: widget.onFullScreen,
      child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            appImage(photo.imagePath,
                cacheWidth: 800,
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
            // Expand hint
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.fullscreen,
                    color: Colors.white70, size: 18),
              ),
            ),
          ],
        ),
      ),
    ), // GestureDetector
    );
  }

  Widget _buildVoiceCard(InspectionPhoto photo) {
    final hasNote = photo.transcription != null && photo.transcription!.isNotEmpty;

    // Inline notes editor (no note yet, or editing)
    if (!hasNote || _editingNotes) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('NOTES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.outline, letterSpacing: 0.5)),
                if (_editingNotes)
                  GestureDetector(
                    onTap: () => setState(() { _editingNotes = false; _isListening = false; try { _speech.stop(); } catch (_) {} }),
                    child: const Text('CANCEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.outline)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _isListening
                    ? AppColors.primary.withOpacity(0.5)
                    : AppColors.outlineVariant.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _toggleListening,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? AppColors.primary.withOpacity(0.2)
                              : AppColors.surfaceContainerHighest,
                          border: Border.all(color: _isListening ? AppColors.primary : AppColors.outlineVariant),
                        ),
                        child: Icon(_isListening ? Icons.stop : Icons.mic,
                            color: _isListening ? AppColors.primary : AppColors.outline, size: 16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _notesCtrl,
                      autofocus: !hasNote,
                      style: const TextStyle(color: AppColors.onSurface, fontSize: 13, height: 1.5),
                      cursorColor: AppColors.primary,
                      maxLines: 4, minLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: _isListening ? 'Listening… speak now' : 'Tap 🎤 or type notes…',
                        hintStyle: const TextStyle(color: AppColors.outline, fontSize: 12, fontStyle: FontStyle.italic),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveNotes,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('SAVE NOTES', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ),
          ],
        ),
      );
    }

    // Has note — show notes text with edit button
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('NOTES',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.outline,
                      letterSpacing: 0.5)),
              GestureDetector(
                onTap: () {
                  _notesCtrl.text = photo.transcription ?? '';
                  setState(() => _editingNotes = true);
                },
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
          const SizedBox(height: 10),
          if (photo.transcription != null && photo.transcription!.isNotEmpty)
            Text(photo.transcription!,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface,
                    height: 1.5)),
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

// ── Full-screen photo viewer (swipeable, modern UI) ──────────────────────────

class FullPhotoScreen extends StatefulWidget {
  final List<InspectionPhoto> photos;
  final int initialIndex;
  const FullPhotoScreen({super.key, required this.photos, required this.initialIndex});

  @override
  State<FullPhotoScreen> createState() => _FullPhotoScreenState();
}

class _FullPhotoScreenState extends State<FullPhotoScreen> {
  late PageController _ctrl;
  late int _current;
  bool _showUI = true; // tap to toggle UI visibility

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _share(InspectionPhoto photo) async {
    try {
      final text = photo.transcription != null && photo.transcription!.isNotEmpty
          ? '${photo.category} — ${photo.transcription}'
          : photo.category;
      await Share.shareXFiles([XFile(photo.imagePath)],
          text: text, subject: 'Site Memo');
    } catch (_) {}
  }

  Future<void> _download(InspectionPhoto photo) async {
    // On iOS, sharing with save option is the standard way to download
    try {
      await Share.shareXFiles([XFile(photo.imagePath)],
          subject: 'Save photo');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Swipeable photo pages with pinch-to-zoom
          PageView.builder(
            controller: _ctrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.photos.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _showUI = !_showUI),
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                child: SizedBox.expand(
                  child: appImage(widget.photos[i].imagePath, fit: BoxFit.cover),
                ),
              ),
            ),
          ),

          // ── Top floating row (tap photo to hide/show) ───────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: AnimatedOpacity(
              opacity: _showUI ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showUI,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        // Back
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.arrow_back,
                                color: Colors.white, size: 17),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Location tag
                        _Bubble(
                          child: Text(photo.category,
                              style: const TextStyle(color: AppColors.primary,
                                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                          borderColor: AppColors.primary.withOpacity(0.45),
                        ),
                        if (photo.isFlagged) ...[
                          const SizedBox(width: 6),
                          _Bubble(
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.flag, color: AppColors.onTertiaryContainer, size: 11),
                              SizedBox(width: 3),
                              Text('FLAGGED', style: TextStyle(
                                  color: AppColors.onTertiaryContainer,
                                  fontSize: 10, fontWeight: FontWeight.w700)),
                            ]),
                            borderColor: AppColors.onTertiaryContainer.withOpacity(0.4),
                          ),
                        ],
                        const Spacer(),
                        // Download
                        GestureDetector(
                          onTap: () => _download(photo),
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.download_outlined,
                                color: Colors.white, size: 17),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Share
                        GestureDetector(
                          onTap: () => _share(photo),
                          child: Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: const Icon(Icons.ios_share,
                                color: Colors.white, size: 17),
                          ),
                        ),
                        if (widget.photos.length > 1) ...[
                          const SizedBox(width: 8),
                          _Bubble(
                            child: Text('${_current + 1} / ${widget.photos.length}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            borderColor: Colors.white.withOpacity(0.15),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom notes overlay (hidden when UI is off) ─────────────────
          if (photo.transcription != null && photo.transcription!.isNotEmpty)
            AnimatedOpacity(
              opacity: _showUI ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.82), Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(photo.transcription!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.6,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ), // Positioned
            ), // AnimatedOpacity
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  const _Bubble({required this.child, required this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: borderColor),
        ),
        child: child,
      );
}
