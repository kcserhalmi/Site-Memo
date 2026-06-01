import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/inspection.dart';
import '../models/inspection_photo.dart';
import '../models/job.dart';
import '../providers/app_provider.dart';
import '../theme/app_colors.dart';
import '../utils/app_prefs.dart';
import '../utils/file_utils.dart';
import '../widgets/glass_card.dart';
import 'tag_note_screen.dart';
import 'photo_detail_screen.dart';

class CameraScreen extends StatefulWidget {
  /// When pushed from InspectionDetailScreen, these are pre-set.
  final String? jobId;
  final String? inspectionId;
  const CameraScreen({super.key, this.jobId, this.inspectionId});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _ctrl;
  bool _cameraReady = false;
  bool _isCapturing = false;
  bool _flashOn = false;
  bool _burstMode = true; // true = save instantly, false = open review screen
  int _cameraIndex = 0;
  int _catIndex = 0;
  int _burstCount = 0; // photos taken in current burst session
  bool _burstFlash = false;
  String? _lastThumb;

  bool get _isDesktop {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_isDesktop) _initCamera();
    // Override provider selection if pushed with specific IDs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.jobId != null && widget.inspectionId != null) {
        context.read<AppProvider>().setSelectedContext(
            widget.jobId!, widget.inspectionId!);
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      await _startController(_cameraIndex);
    } catch (_) {}
  }

  Future<void> _startController(int index) async {
    await _ctrl?.dispose();
    _ctrl = CameraController(_cameras[index], ResolutionPreset.high,
        enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    await _ctrl!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _cameraReady = false);
    _cameraIndex = _cameraIndex == 0 ? 1 : 0;
    await _startController(_cameraIndex);
  }

  Future<void> _toggleFlash() async {
    if (!_cameraReady || _ctrl == null) return;
    _flashOn = !_flashOn;
    await _ctrl!.setFlashMode(
        _flashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    if (s == AppLifecycleState.inactive) {
      _ctrl!.dispose();
      setState(() => _cameraReady = false);
    } else if (s == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.dispose();
    super.dispose();
  }

  String _activeLocation(Inspection? insp) {
    final cats = insp?.categories ?? [];
    if (cats.isEmpty) return 'UNTAGGED';
    final idx = _catIndex - 1; // strip index 0 = ALL
    if (idx >= 0 && idx < cats.length) return cats[idx];
    return cats.first;
  }

  Future<void> _capture(BuildContext context) async {
    if (_isCapturing) return;
    final provider = context.read<AppProvider>();
    final site = provider.selectedSite;
    final insp = provider.selectedInspection;

    if (site == null || insp == null) {
      _showSiteSelector(context);
      return;
    }

    setState(() => _isCapturing = true);
    try {
      XFile? file;
      if (_cameraReady && _ctrl != null) {
        file = await _ctrl!.takePicture();
      } else {
        final src = _isDesktop ? ImageSource.gallery : ImageSource.camera;
        final hq = await AppPrefs.getHighQuality();
        file = await ImagePicker().pickImage(
          source: src,
          imageQuality: hq ? 100 : 82,
          maxWidth: hq ? 4096 : 2048,
        );
      }
      if (file == null || !mounted) return;

      setState(() => _lastThumb = file!.path);
      final location = _activeLocation(insp);

      if (_burstMode) {
        // ── BURST: save instantly, stay in camera ──────────────────────
        final photo = InspectionPhoto(
          id: provider.generateId(),
          jobId: site.id,
          inspectionId: insp.id,
          imagePath: file.path,
          category: location,
          timestamp: DateTime.now(),
        );
        await provider.addPhoto(site.id, insp.id, photo);
        setState(() { _burstCount++; _burstFlash = true; });
        Future.delayed(const Duration(milliseconds: 220), () {
          if (mounted) setState(() => _burstFlash = false);
        });
      } else {
        // ── REVIEW: fully release camera before navigating on iOS ───────
        if (_ctrl != null) {
          await _ctrl!.dispose();
          _ctrl = null;
          if (mounted) setState(() => _cameraReady = false);
        }
        // ── Open tag + voice note screen ────────────────────────────────
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TagNoteScreen(
              imagePath: file!.path,
              jobId: site.id,
              inspectionId: insp.id,
              initialCategory: location,
            ),
          ),
        );
        // Reinitialize camera after returning from review screen
        if (mounted && !_isDesktop) _initCamera();
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _addLocationTag(BuildContext context) {
    final provider = context.read<AppProvider>();
    final insp = provider.selectedInspection;
    final site = provider.selectedSite;
    if (insp == null || site == null) return;

    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Add Location',
            style: TextStyle(
                color: AppColors.onSurface, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: AppColors.onSurface, fontSize: 15),
          cursorColor: AppColors.primary,
          decoration: const InputDecoration(
            hintText: 'e.g. UNIT 201, LEVEL 3 EAST…',
            hintStyle: TextStyle(color: AppColors.outline, fontSize: 13),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.outlineVariant)),
            focusedBorder: UnderlineInputBorder(
                borderSide:
                    BorderSide(color: AppColors.primaryContainer, width: 2)),
          ),
          onSubmitted: (_) => _saveNewLocation(dCtx, ctrl.text, insp, site, provider),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.outline, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => _saveNewLocation(dCtx, ctrl.text, insp, site, provider),
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

  Future<void> _saveNewLocation(BuildContext dCtx, String raw,
      dynamic insp, dynamic site, AppProvider provider) async {
    final tag = raw.trim().toUpperCase();
    if (tag.isEmpty) { Navigator.pop(dCtx); return; }
    final existing = List<String>.from(insp.categories ?? []);
    if (!existing.contains(tag)) {
      existing.add(tag);
      await provider.updateInspectionCategories(site.id, insp.id, existing);
    }
    // Auto-select the new tag
    final newIndex = existing.indexOf(tag) + 1; // +1 for ALL at index 0
    setState(() => _catIndex = newIndex);
    if (dCtx.mounted) Navigator.pop(dCtx);
  }

  // ── Site + Inspection selector sheet ──────────────────────────────────────
  void _showSiteSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SiteSelectorSheet(
        onSelected: (siteId, inspId) {
          context.read<AppProvider>().setSelectedContext(siteId, inspId);
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final site = provider.selectedSite;
    final insp = provider.selectedInspection;
    final cats = insp != null && insp.categories.isNotEmpty
        ? ['ALL', ...insp.categories]
        : ['ALL'];
    final canPop = Navigator.canPop(context);
    final canFlip = _cameras.length > 1 || kIsWeb;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildViewfinder(),
          // Burst save flash — green border confirming photo saved
          if (_burstFlash)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _burstFlash ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 80),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.secondary, width: 4),
                    ),
                  ),
                ),
              ),
            ),
          // ── Top overlay ──────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Row 1: back / site-inspection selector / flip / flash
                    Row(
                      children: [
                        if (canPop) ...[
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: GlassCard(
                              padding: const EdgeInsets.all(9),
                              borderRadius: BorderRadius.circular(99),
                              child: const Icon(Icons.arrow_back,
                                  color: AppColors.onSurface, size: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showSiteSelector(context),
                            child: GlassCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              borderRadius: BorderRadius.circular(10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          site?.name ?? 'Select a site',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: site != null
                                                ? AppColors.primary
                                                : AppColors.outline,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          insp != null
                                              ? '${insp.dateLabel} • ${insp.title}'
                                              : 'Tap to select inspection',
                                          style: const TextStyle(
                                              fontSize: 9,
                                              color: AppColors.onSurfaceVariant),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.expand_more,
                                      color: AppColors.outline, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (canFlip) ...[
                          GestureDetector(
                            onTap: _flipCamera,
                            child: GlassCard(
                              padding: const EdgeInsets.all(9),
                              borderRadius: BorderRadius.circular(99),
                              child: const Icon(Icons.flip_camera_ios,
                                  color: AppColors.onSurface, size: 18),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        GestureDetector(
                          onTap: _toggleFlash,
                          child: GlassCard(
                            padding: const EdgeInsets.all(9),
                            borderRadius: BorderRadius.circular(99),
                            child: Icon(
                              _flashOn ? Icons.bolt : Icons.bolt_outlined,
                              color: _flashOn
                                  ? AppColors.primaryContainer
                                  : _cameraReady
                                      ? AppColors.primary
                                      : AppColors.outline,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row 2: BURST/REVIEW toggle + active location + photo count
                    Row(
                      children: [
                        // Mode toggle pill
                        GlassCard(
                          padding: const EdgeInsets.all(3),
                          borderRadius: BorderRadius.circular(99),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ModeBtn(
                                label: 'BURST',
                                icon: Icons.bolt,
                                active: _burstMode,
                                onTap: () => setState(() {
                                  _burstMode = true;
                                  _burstCount = 0;
                                }),
                              ),
                              _ModeBtn(
                                label: 'REVIEW',
                                icon: Icons.rate_review_outlined,
                                active: !_burstMode,
                                onTap: () => setState(() => _burstMode = false),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Active location tag
                        Expanded(
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            borderRadius: BorderRadius.circular(99),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    color: AppColors.primaryFixedDim, size: 12),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    _activeLocation(insp),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                        letterSpacing: 0.3),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Burst counter badge
                        if (_burstMode && _burstCount > 0) ...[
                          const SizedBox(width: 8),
                          GlassCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            borderRadius: BorderRadius.circular(99),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_camera,
                                    color: AppColors.secondary, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '$_burstCount',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.secondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _Reticle(),
          // Category strip
          Positioned(
            bottom: 96, left: 0, right: 0,
            child: _CategoryStrip(
              categories: cats,
              selectedIndex: _catIndex.clamp(0, cats.length - 1),
              onSelect: (i) => setState(() => _catIndex = i),
              onAddLocation: () => _addLocationTag(context),
            ),
          ),
          // Shutter row
          Positioned(
            bottom: 16, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    final insp = context.read<AppProvider>().selectedInspection;
                    if (insp != null && insp.photos.isNotEmpty) {
                      final last = insp.photos.last;
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PhotoDetailScreen(
                          photos: insp.photos,
                          initialIndex: insp.photos.length - 1),
                      ));
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 48, height: 48,
                      child: _lastThumb != null
                          ? appImage(_lastThumb!)
                          : Container(color: AppColors.surfaceContainerHigh),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isCapturing ? null : () => _capture(context),
                  child: AnimatedScale(
                    scale: _isCapturing ? 0.9 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      width: 76, height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25), width: 2),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Container(
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white)),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: canFlip ? _flipCamera : null,
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    borderRadius: BorderRadius.circular(99),
                    child: Icon(Icons.flip_camera_ios,
                        color: canFlip ? AppColors.onSurface : AppColors.outline,
                        size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinder() {
    if (_cameraReady && _ctrl != null && _ctrl!.value.isInitialized) {
      return CameraPreview(_ctrl!);
    }
    return Container(
      color: const Color(0xFF0D0D0D),
      child: CustomPaint(painter: _GridPainter(), size: Size.infinite),
    );
  }
}

// ── Site selector bottom sheet ────────────────────────────────────────────────

class _SiteSelectorSheet extends StatefulWidget {
  final void Function(String siteId, String inspectionId) onSelected;
  const _SiteSelectorSheet({required this.onSelected});

  @override
  State<_SiteSelectorSheet> createState() => _SiteSelectorSheetState();
}

class _SiteSelectorSheetState extends State<_SiteSelectorSheet> {
  String? _pendingSiteId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final activeSites = provider.activeJobs;
    final currentSiteId =
        _pendingSiteId ?? provider.selectedSite?.id ?? (activeSites.isNotEmpty ? activeSites.first.id : null);
    final currentSite = currentSiteId != null
        ? activeSites.firstWhere((j) => j.id == currentSiteId,
            orElse: () => activeSites.isNotEmpty ? activeSites.first : activeSites.first)
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.outline.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('SELECT SITE',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.outline,
                      letterSpacing: 0.5)),
              const SizedBox(height: 10),
              // Site list
              ...activeSites.map((site) {
                final selected = site.id == currentSiteId;
                return GestureDetector(
                  onTap: () => setState(() => _pendingSiteId = site.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryContainer.withOpacity(0.15)
                          : AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: selected
                              ? AppColors.primaryContainer
                              : AppColors.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(site.name,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.onSurface)),
                              Text(site.location,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle,
                              color: AppColors.primary, size: 18),
                      ],
                    ),
                  ),
                );
              }),
              if (activeSites.isEmpty)
                const Text('No active sites. Create one from the Jobs tab.',
                    style: TextStyle(color: AppColors.outline, fontSize: 13)),
              if (currentSite != null) ...[
                const SizedBox(height: 20),
                const Text('SELECT INSPECTION',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.outline,
                        letterSpacing: 0.5)),
                const SizedBox(height: 10),
                if (currentSite.inspections.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: const Text(
                        'No inspections for this site yet.\nCreate one from the site\'s page first.',
                        style: TextStyle(color: AppColors.outline, fontSize: 13)),
                  )
                else ...[
                  ...(() {
                    final sorted = [...currentSite.inspections]
                      ..sort((a, b) => b.date.compareTo(a.date));
                    return sorted.map((insp) {
                      final currentInspId = provider.selectedInspection?.id;
                      final isSameSite = currentSiteId == provider.selectedSite?.id;
                      final isSelected = isSameSite && insp.id == currentInspId;
                      return GestureDetector(
                        onTap: () {
                          widget.onSelected(currentSite.id, insp.id);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryContainer.withOpacity(0.15)
                                : AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryContainer
                                    : AppColors.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(insp.title,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.onSurface)),
                                    Text(insp.dateLabel,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              Text('${insp.photoCount}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.outline)),
                              const SizedBox(width: 4),
                              const Icon(Icons.photo_outlined,
                                  size: 12, color: AppColors.outline),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.check_circle,
                                    color: AppColors.primary, size: 18),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList();
                  })(),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Camera UI helpers ─────────────────────────────────────────────────────────

class _Reticle extends StatelessWidget {
  const _Reticle();
  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 180, height: 180,
          child: Stack(children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.35), width: 1.5),
              ),
            ),
            _c(true, true), _c(true, false), _c(false, true), _c(false, false),
          ]),
        ),
      );

  Widget _c(bool top, bool left) => Positioned(
        top: top ? -1 : null, bottom: top ? null : -1,
        left: left ? -1 : null, right: left ? null : -1,
        child: SizedBox(
          width: 20, height: 20,
          child: CustomPaint(painter: _CP(top: top, left: left)),
        ),
      );
}

class _CP extends CustomPainter {
  final bool top, left;
  const _CP({required this.top, required this.left});
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final x = left ? 0.0 : s.width;
    final y = top ? 0.0 : s.height;
    c.drawLine(Offset(x, y), Offset(x + (left ? s.width : -s.width), y), p);
    c.drawLine(Offset(x, y), Offset(x, y + (top ? s.height : -s.height)), p);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 3; i++) {
      c.drawLine(Offset(s.width * i / 3, 0), Offset(s.width * i / 3, s.height), p);
      c.drawLine(Offset(0, s.height * i / 3), Offset(s.width, s.height * i / 3), p);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

class _CategoryStrip extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAddLocation;
  const _CategoryStrip(
      {required this.categories,
      required this.selectedIndex,
      required this.onSelect,
      required this.onAddLocation});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...List.generate(categories.length, (i) {
            final active = i == selectedIndex;
            return GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(categories[i],
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? AppColors.primary
                                : AppColors.onSurface.withOpacity(0.4),
                            letterSpacing: 0.4)),
                    const SizedBox(height: 3),
                    if (active)
                      Container(
                          width: 24,
                          height: 2,
                          decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(99))),
                  ],
                ),
              ),
            );
          }),
          // + Add location
          GestureDetector(
            onTap: onAddLocation,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                    color: AppColors.outlineVariant.withOpacity(0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_location_alt_outlined,
                      color: AppColors.outline, size: 13),
                  SizedBox(width: 4),
                  Text('ADD',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.outline,
                          letterSpacing: 0.3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mode toggle button ────────────────────────────────────────────────────────

class _ModeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ModeBtn(
      {required this.label,
      required this.icon,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryContainer.withOpacity(0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: active ? AppColors.primary : AppColors.outline,
                  size: 13),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.primary : AppColors.outline,
                      letterSpacing: 0.3)),
            ],
          ),
        ),
      );
}
