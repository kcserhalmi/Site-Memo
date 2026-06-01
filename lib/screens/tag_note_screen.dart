import 'package:flutter/material.dart';
import '../utils/app_prefs.dart';
import '../utils/file_utils.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/inspection_photo.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/waveform_visualizer.dart';

class TagNoteScreen extends StatefulWidget {
  final String imagePath;
  final String jobId;
  final String inspectionId;
  final String initialCategory;

  const TagNoteScreen({
    super.key,
    required this.imagePath,
    required this.jobId,
    required this.inspectionId,
    this.initialCategory = 'EXTERIOR',
  });

  @override
  State<TagNoteScreen> createState() => _TagNoteScreenState();
}

IconData _iconForCategory(String cat) {
  switch (cat.toUpperCase()) {
    case 'EXTERIOR': return Icons.home_outlined;
    case 'STRUCTURAL': return Icons.grid_view_outlined;
    case 'DAMAGE': return Icons.warning_amber_outlined;
    case 'INTERIOR': return Icons.crop_square_outlined;
    case 'FOUNDATION': return Icons.layers_outlined;
    case 'ELECTRICAL': return Icons.electrical_services_outlined;
    case 'PLUMBING': return Icons.plumbing_outlined;
    case 'ROOFING': return Icons.roofing_outlined;
    case 'SAFETY': return Icons.health_and_safety_outlined;
    default: return Icons.label_outline;
  }
}

class _TagNoteScreenState extends State<TagNoteScreen> {
  List<String> _jobCategories = [];
  late String _selectedCat;
  final _captionCtrl = TextEditingController();
  final _recorder = AudioRecorder();
  final _speech = SpeechToText();
  bool _speechAvail = false;
  bool _isRecording = false;
  String _transcription = '';
  final _transcriptionCtrl = TextEditingController();
  String? _audioPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCat = widget.initialCategory;
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      final job = provider.jobs.firstWhere(
        (j) => j.id == widget.jobId,
        orElse: () => provider.jobs.first,
      );
      final insp = job.inspections.firstWhere(
        (i) => i.id == widget.inspectionId,
        orElse: () => job.inspections.isNotEmpty ? job.inspections.first : job.inspections.first,
      );
      setState(() => _jobCategories = List.from(insp.categories));
    });
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvail = await _speech.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      _speechAvail = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      _audioPath = await _recorder.stop();
      try {
        await _speech.stop();
      } catch (_) {}
      setState(() => _isRecording = false);
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showSnack('Microphone permission denied');
        return;
      }
      final path = await getAudioRecordPath();

      try {
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      } catch (e) {
        _showSnack('Could not start recording: $e');
        return;
      }

      final autoTranscribe = await AppPrefs.getAutoTranscribe();
      if (_speechAvail && autoTranscribe) {
        try {
          await _speech.listen(
            onResult: (r) {
              if (mounted) {
                setState(() {
                  _transcription = r.recognizedWords;
                  _transcriptionCtrl.text = _transcription;
                });
              }
            },
            listenOptions: SpeechListenOptions(
              cancelOnError: false,
              partialResults: true,
            ),
          );
        } catch (_) {}
      }
      setState(() => _isRecording = true);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final finalTranscription = _transcriptionCtrl.text.trim().isNotEmpty
        ? _transcriptionCtrl.text.trim()
        : _transcription.trim();

    final photo = InspectionPhoto(
      id: context.read<AppProvider>().generateId(),
      jobId: widget.jobId,
      inspectionId: widget.inspectionId,
      imagePath: widget.imagePath,
      voiceNotePath: _audioPath,
      transcription: finalTranscription.isNotEmpty ? finalTranscription : null,
      caption: _captionCtrl.text.trim().isNotEmpty ? _captionCtrl.text.trim() : null,
      category: _selectedCat,
      timestamp: DateTime.now(),
    );

    await context.read<AppProvider>().addPhoto(widget.jobId, widget.inspectionId, photo);
    if (mounted) Navigator.pop(context);
  }

  void _showAddTagDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('New Tag',
            style: TextStyle(
                color: AppColors.onSurface, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: AppColors.onSurface),
          cursorColor: AppColors.primary,
          decoration: const InputDecoration(
            hintText: 'e.g. UNIT 3B, ROOFING…',
            hintStyle: TextStyle(color: AppColors.outline, fontSize: 13),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.outlineVariant)),
            focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.primaryContainer, width: 2)),
          ),
          onSubmitted: (_) => _saveNewTag(dCtx, ctrl.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.outline, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => _saveNewTag(dCtx, ctrl.text),
            child: const Text('ADD',
                style: TextStyle(
                    color: AppColors.primaryContainer,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveNewTag(BuildContext dCtx, String raw) async {
    final tag = raw.trim().toUpperCase();
    if (tag.isEmpty || _jobCategories.contains(tag)) {
      Navigator.pop(dCtx);
      return;
    }
    final updated = [..._jobCategories, tag];
    await context.read<AppProvider>().updateInspectionCategories(
        widget.jobId, widget.inspectionId, updated);
    setState(() {
      _jobCategories = updated;
      _selectedCat = tag;
    });
    if (dCtx.mounted) Navigator.pop(dCtx);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.surfaceContainerHigh,
      ),
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    _captionCtrl.dispose();
    _transcriptionCtrl.dispose();
    try {
      _speech.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPhotoPreview(),
                    const SizedBox(height: 16),
                    _buildCaptionField(),
                    const SizedBox(height: 20),
                    _buildCategorySection(),
                    const SizedBox(height: 24),
                    _buildVoiceNoteSection(),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text('CANCEL',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.4)),
          ),
          Column(
            children: [
              const Text('REVIEW',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.outline,
                      letterSpacing: 0.5)),
              Text(
                _formatDateTime(DateTime.now()),
                style: const TextStyle(
                    fontSize: 10, color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          GestureDetector(
            onTap: _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                  )
                : const Text('SAVE',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 192,
          height: 192,
          child: appImage(widget.imagePath),
        ),
      ),
    );
  }

  Widget _buildCaptionField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
      ),
      child: TextField(
        controller: _captionCtrl,
        style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
        cursorColor: AppColors.primary,
        maxLines: 2,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Quick label… (e.g. "Crack near window sill")',
          hintStyle: TextStyle(color: AppColors.outline, fontSize: 13),
          prefixIcon: Icon(Icons.label_outline, color: AppColors.outline, size: 18),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('LOCATION',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.outline,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.1,
          children: [
            ...(_jobCategories.isNotEmpty ? _jobCategories : ['UNTAGGED'])
                .map((cat) {
              final active = cat == _selectedCat;
              final isDamage = cat == 'DAMAGE';
              final activeColor =
                  isDamage ? AppColors.onTertiaryContainer : AppColors.primary;
              return GestureDetector(
                onTap: () => setState(() => _selectedCat = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: active
                        ? activeColor.withOpacity(0.1)
                        : const Color(0x991E1E1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active
                          ? activeColor
                          : Colors.white.withOpacity(0.08),
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_iconForCategory(cat),
                          color: active ? activeColor : AppColors.outline,
                          size: 22),
                      const SizedBox(height: 6),
                      Text(cat,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: active ? activeColor : AppColors.outline,
                              letterSpacing: 0.3)),
                    ],
                  ),
                ),
              );
            }),
            // + ADD TAG tile
            GestureDetector(
              onTap: () => _showAddTagDialog(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: const Color(0x991E1E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.outlineVariant.withOpacity(0.4),
                      style: BorderStyle.solid),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppColors.outline, size: 22),
                    SizedBox(height: 6),
                    Text('ADD TAG',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.outline,
                            letterSpacing: 0.3)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoiceNoteSection() {
    return Column(
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
            if (_transcription.isNotEmpty || _transcriptionCtrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _transcription = '';
                    _transcriptionCtrl.clear();
                    _audioPath = null;
                  });
                },
                child: const Text('CLEAR',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        GlassCard(
          child: Column(
            children: [
              // Record button + waveform
              Row(
                children: [
                  GestureDetector(
                    onTap: _toggleRecord,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? AppColors.errorContainer
                            : AppColors.surfaceContainerHigh,
                        boxShadow: _isRecording
                            ? [
                                BoxShadow(
                                    color: AppColors.errorContainer
                                        .withOpacity(0.4),
                                    blurRadius: 12)
                              ]
                            : [],
                      ),
                      child: Center(
                        child: _isRecording
                            ? Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.error,
                                ),
                              )
                            : const Icon(Icons.mic,
                                color: AppColors.onSurface, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WaveformVisualizer(
                      isActive: _isRecording,
                      barCount: 16,
                      height: 36,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isRecording)
                    const Text('REC',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                            letterSpacing: 0.4))
                  else if (_audioPath != null)
                    const Icon(Icons.check_circle,
                        color: AppColors.secondary, size: 18),
                ],
              ),
              // Transcription
              if (_isRecording || _transcription.isNotEmpty ||
                  _transcriptionCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: _isRecording && !_speechAvail
                      ? const Text(
                          'Recording… transcription will appear when done.',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.outline,
                              fontStyle: FontStyle.italic),
                        )
                      : TextField(
                          controller: _transcriptionCtrl,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.onSurface,
                              fontStyle: FontStyle.italic),
                          maxLines: null,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Transcription will appear here…',
                            hintStyle: TextStyle(
                                color: AppColors.outline,
                                fontStyle: FontStyle.italic),
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _toggleRecord,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.outlineVariant.withOpacity(0.5),
                          style: BorderStyle.solid),
                    ),
                    child: const Text(
                      'Tap mic to record voice note',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.outline,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 8,
          shadowColor: AppColors.primary.withOpacity(0.3),
        ),
        child: const Text('SAVE PHOTO',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 1.0)),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day} • $h:$m';
  }
}
