import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_card.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            // Profile card
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Field Inspector',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurface)),
                        SizedBox(height: 2),
                        Text('Site Memo Pro',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.outline)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: AppColors.secondary.withOpacity(0.3)),
                    ),
                    child: const Text('PRO',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                            letterSpacing: 0.4)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('PREFERENCES'),
            const SizedBox(height: 8),
            _SettingRow(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              trailing: Switch(
                value: true,
                onChanged: (_) {},
                activeColor: AppColors.primary,
                activeTrackColor: AppColors.primaryContainer.withOpacity(0.3),
              ),
            ),
            _SettingRow(
              icon: Icons.mic_outlined,
              label: 'Auto-Transcribe Voice Notes',
              trailing: Switch(
                value: true,
                onChanged: (_) {},
                activeColor: AppColors.primary,
                activeTrackColor: AppColors.primaryContainer.withOpacity(0.3),
              ),
            ),
            _SettingRow(
              icon: Icons.high_quality_outlined,
              label: 'High Quality Photos',
              trailing: Switch(
                value: false,
                onChanged: (_) {},
                activeColor: AppColors.primary,
                activeTrackColor: AppColors.primaryContainer.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('APP'),
            const SizedBox(height: 8),
            _SettingRow(
              icon: Icons.info_outline,
              label: 'Version',
              trailing: const Text('1.0.0',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.outline)),
            ),
            _SettingRow(
              icon: Icons.storage_outlined,
              label: 'Clear Cache',
              trailing: const Icon(Icons.chevron_right,
                  color: AppColors.outline, size: 20),
            ),
            const SizedBox(height: 32),
            Container(
              height: 1,
              color: AppColors.outlineVariant.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
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
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.outline,
            letterSpacing: 0.5));
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.outline, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.onSurface)),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
