import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_colors.dart';
import '../widgets/press_scale.dart';

/// Shown full-screen when the free trial ends, or pushed from the trial
/// banner. Purchases activate once the App Store subscription products
/// exist — until then the buttons explain that.
class PaywallScreen extends StatefulWidget {
  /// When true the trial is over: no close button, only subscribe or
  /// sign out.
  final bool blocking;
  const PaywallScreen({super.key, this.blocking = false});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _annual = true;

  void _notLiveYet() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content:
          Text('Subscriptions activate once the App Store listing is live.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final status = SubscriptionService.current;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color:
                                AppColors.primaryContainer.withOpacity(0.14),
                            border: Border.all(
                                color: AppColors.primaryContainer
                                    .withOpacity(0.45)),
                          ),
                          child: const Icon(Icons.photo_camera_outlined,
                              color: AppColors.primary, size: 24),
                        ),
                        if (!widget.blocking)
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close,
                                color: AppColors.outline),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.blocking
                          ? 'Your free trial\nhas ended'
                          : 'Site Memo Pro',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: -0.5,
                          color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.blocking
                          ? 'Keep documenting your sites — your data is safe and waiting.'
                          : status.isTrialActive
                              ? '${status.trialDaysLeft} day${status.trialDaysLeft == 1 ? '' : 's'} left in your free trial.'
                              : 'Everything you need in the field.',
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant,
                          height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    const _Feature(
                        icon: Icons.cloud_done_outlined,
                        title: 'Unlimited photos, backed up',
                        subtitle:
                            'Every photo saved to the cloud automatically'),
                    const _Feature(
                        icon: Icons.devices_outlined,
                        title: 'All your devices',
                        subtitle:
                            'Sign in anywhere — phone, tablet, computer'),
                    const _Feature(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'Professional reports',
                        subtitle:
                            'Branded PDF reports grouped by location, ready for clients'),
                    const _Feature(
                        icon: Icons.flag_outlined,
                        title: 'Never lose an issue',
                        subtitle:
                            'Flag problems, track follow-ups, search everything'),
                    const SizedBox(height: 24),
                    // Plan picker
                    Row(
                      children: [
                        Expanded(
                          child: _PlanCard(
                            title: 'Annual',
                            price: SubscriptionPricing.annual,
                            per: '/year',
                            badge: SubscriptionPricing.annualSavings,
                            selected: _annual,
                            onTap: () => setState(() => _annual = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PlanCard(
                            title: 'Monthly',
                            price: SubscriptionPricing.monthly,
                            per: '/month',
                            selected: !_annual,
                            onTap: () => setState(() => _annual = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            // Bottom actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _notLiveYet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.onPrimaryContainer,
                      ),
                      child: Text(
                        'SUBSCRIBE — ${_annual ? '${SubscriptionPricing.annual}/yr' : '${SubscriptionPricing.monthly}/mo'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, letterSpacing: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _notLiveYet,
                        child: const Text('Restore Purchases',
                            style: TextStyle(
                                color: AppColors.outline, fontSize: 12)),
                      ),
                      if (widget.blocking)
                        TextButton(
                          onPressed: () async {
                            try {
                              await AuthService().signOut();
                            } catch (_) {}
                          },
                          child: const Text('Sign Out',
                              style: TextStyle(
                                  color: AppColors.outline, fontSize: 12)),
                        ),
                    ],
                  ),
                  const Text(
                    'Cancel anytime. Subscription renews automatically until cancelled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: AppColors.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Feature(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.primaryContainer.withOpacity(0.12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String per;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  const _PlanCard({
    required this.title,
    required this.price,
    required this.per,
    this.badge,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        pressedScale: 0.97,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryContainer.withOpacity(0.12)
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primaryContainer
                  : AppColors.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant)),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(badge!,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(price,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface)),
              Text(per,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.outline)),
            ],
          ),
        ),
      );
}
