import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../theme/app_colors.dart';
import '../main_shell.dart';
import '../paywall_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  final String? firebaseError;
  const AuthGate({super.key, this.firebaseError});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  StreamSubscription<User?>? _sub;
  User? _user;
  SubscriptionStatus? _subStatus;
  bool _ready = false;
  bool _demoStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.firebaseError != null) {
      _ready = true;
      return;
    }
    _sub = _authService.authStateChanges.listen((user) async {
      if (!mounted) return;
      await context.read<AppProvider>().setCurrentUser(user?.uid);
      // Trial/subscription check — fail-open so a network blip never
      // locks anyone out.
      SubscriptionStatus? status;
      if (user != null) {
        try {
          status = await SubscriptionService.check();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _user = user;
        _subStatus = status;
        _ready = true;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.firebaseError != null) {
      if (_demoStarted) return const MainShell();
      return _FirebaseSetupError(
        error: widget.firebaseError!,
        onDemoMode: () async {
          await context.read<AppProvider>().enterDemoMode();
          if (mounted) setState(() => _demoStarted = true);
        },
      );
    }
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_user == null) return const LoginScreen();
    // Trial over and not subscribed — blocking paywall
    if (_subStatus != null && !_subStatus!.hasAccess) {
      return const PaywallScreen(blocking: true);
    }
    return const MainShell();
  }
}

class _FirebaseSetupError extends StatelessWidget {
  final String error;
  final VoidCallback onDemoMode;
  const _FirebaseSetupError({required this.error, required this.onDemoMode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off, color: AppColors.error, size: 40),
              const SizedBox(height: 16),
              const Text('Firebase isn\'t configured\non this device',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: AppColors.onSurface)),
              const SizedBox(height: 12),
              const Text(
                'Sign-in and cloud sync need Firebase credentials. Run '
                '"flutterfire configure" from the project root to generate '
                'lib/firebase_options.dart for this platform, then rebuild.\n\n'
                'You can still explore the full app with sample data — '
                'nothing will be saved or synced.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onDemoMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                  ),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('EXPLORE IN DEMO MODE',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(height: 20),
              Text(error,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.outline, fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    );
  }
}
