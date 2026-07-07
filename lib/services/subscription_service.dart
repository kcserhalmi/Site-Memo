import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pricing shown in the paywall. Once the App Store products exist these
/// come from StoreKit/RevenueCat instead of constants.
class SubscriptionPricing {
  static const monthly = r'$9.99';
  static const annual = r'$79.99';
  static const annualSavings = 'Save 33%';
}

class SubscriptionStatus {
  final bool isPro; // paid subscriber (or manually granted)
  final int trialDaysLeft; // 0 when the trial is over
  const SubscriptionStatus({required this.isPro, required this.trialDaysLeft});

  bool get isTrialActive => trialDaysLeft > 0;
  bool get hasAccess => isPro || isTrialActive;

  static const none = SubscriptionStatus(isPro: false, trialDaysLeft: 0);
}

/// Free-trial-then-subscribe model. The trial clock starts at account
/// creation (Firebase Auth metadata), so reinstalling doesn't reset it.
///
/// TODO(App Store): when the Apple developer account + subscription products
/// exist, integrate RevenueCat (purchases_flutter) and replace the
/// `proOverride` lookup with a real entitlement check. Until then a user can
/// be granted Pro manually by setting `proOverride: true` on their
/// users/{uid} doc in the Firebase console.
class SubscriptionService {
  static const trialLengthDays = 14;

  /// Last fetched status — lets widgets (e.g. the dashboard trial banner)
  /// read it without re-querying.
  static SubscriptionStatus current = SubscriptionStatus.none;

  static Future<SubscriptionStatus> check() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Firebase not initialized (demo mode) — no gating.
      current = const SubscriptionStatus(
          isPro: false, trialDaysLeft: trialLengthDays);
      return current;
    }
    if (user == null) {
      current = SubscriptionStatus.none;
      return current;
    }

    bool pro = false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      pro = (doc.data()?['proOverride'] as bool?) ?? false;
    } catch (_) {
      // Offline — don't lock a paying user out over a network blip.
      // Keep whatever we knew last.
      pro = current.isPro;
    }

    final created = user.metadata.creationTime ?? DateTime.now();
    final daysUsed = DateTime.now().difference(created).inDays;
    final left =
        (trialLengthDays - daysUsed).clamp(0, trialLengthDays);

    current = SubscriptionStatus(isPro: pro, trialDaysLeft: left);
    return current;
  }
}
