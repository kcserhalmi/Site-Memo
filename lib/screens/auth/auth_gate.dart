import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../main_shell.dart';
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
  bool _ready = false;

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
      if (!mounted) return;
      setState(() {
        _user = user;
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
      return _FirebaseSetupError(error: widget.firebaseError!);
    }
    if (!_ready) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return _user == null ? const LoginScreen() : const MainShell();
  }
}

class _FirebaseSetupError extends StatelessWidget {
  final String error;
  const _FirebaseSetupError({required this.error});

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
              const Text('Firebase isn\'t configured yet',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface)),
              const SizedBox(height: 12),
              const Text(
                'Run "flutterfire configure" from the project root to '
                'generate lib/firebase_options.dart with your real Firebase '
                'project credentials, then rebuild the app.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: 16),
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
