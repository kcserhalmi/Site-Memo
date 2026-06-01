import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/app_prefs.dart';
import '../widgets/glass_card.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameCtrl = TextEditingController();
  bool _autoTranscribe = true;
  bool _highQuality = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await AppPrefs.getInspectorName();
    final at = await AppPrefs.getAutoTranscribe();
    final hq = await AppPrefs.getHighQuality();
    if (mounted) {
      setState(() {
        _nameCtrl.text = name;
        _autoTranscribe = at;
        _highQuality = hq;
        _loaded = true;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Text('Account',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface)),
            const SizedBox(height: 24),

            // ── Profile card ────────────────────────────────────────────
            GlassCard(
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainerHigh,
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.person,
                        color: AppColors.outline, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameCtrl.text.isNotEmpty
                              ? _nameCtrl.text
                              : 'Field Inspector',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface),
                        ),
                        const Text('Site Memo',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.outline)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Inspector name ──────────────────────────────────────────
            const _SectionLabel('YOUR NAME'),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _nameCtrl,
                style: const TextStyle(
                    color: AppColors.onSurface, fontSize: 15),
                cursorColor: AppColors.primary,
                onChanged: (v) => setState(() {}),
                onSubmitted: (v) => AppPrefs.setInspectorName(v.trim()),
                onEditingComplete: () =>
                    AppPrefs.setInspectorName(_nameCtrl.text.trim()),
                decoration: const InputDecoration(
                  hintText: 'Your name (auto-fills on inspections)',
                  hintStyle:
                      TextStyle(color: AppColors.outline, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Saved automatically as you type',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.outline.withOpacity(0.7)),
              ),
            ),
            const SizedBox(height: 20),

            // ── Preferences ─────────────────────────────────────────────
            const _SectionLabel('PREFERENCES'),
            const SizedBox(height: 8),
            _SettingRow(
              icon: Icons.mic_outlined,
              label: 'Auto-Transcribe Voice Notes',
              subtitle: 'Converts recordings to text automatically',
              value: _autoTranscribe,
              onChanged: (v) async {
                setState(() => _autoTranscribe = v);
                await AppPrefs.setAutoTranscribe(v);
              },
            ),
            _SettingRow(
              icon: Icons.high_quality_outlined,
              label: 'High Quality Photos',
              subtitle: 'Larger files, more storage used',
              value: _highQuality,
              onChanged: (v) async {
                setState(() => _highQuality = v);
                await AppPrefs.setHighQuality(v);
              },
            ),
            const SizedBox(height: 20),

            // ── App info ────────────────────────────────────────────────
            const _SectionLabel('APP'),
            const SizedBox(height: 8),
            GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.info_outline,
                        color: AppColors.outline, size: 20),
                    SizedBox(width: 14),
                    Text('Version',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.onSurface)),
                  ]),
                  Text('1.0.0',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.outline)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  const Text('Site Memo',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('Built for the field.',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.outline.withOpacity(0.6))),
                ],
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
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.outline,
          letterSpacing: 0.5));
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: AppColors.outline, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.onSurface)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.outline)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              activeTrackColor: AppColors.primaryContainer.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }
}
