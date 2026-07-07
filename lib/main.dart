import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cap image cache at 50MB — prevents OOM on older iPhones
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;
  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (_) {}
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  String? firebaseError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    firebaseError = e.toString();
  }

  final provider = AppProvider();

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: SiteMemoApp(firebaseError: firebaseError),
    ),
  );
}

bool get _isDesktop {
  if (kIsWeb) return true; // show phone frame in browser too
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class SiteMemoApp extends StatelessWidget {
  final String? firebaseError;
  const SiteMemoApp({super.key, this.firebaseError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Site Memo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101114),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD79B),
          onPrimary: Color(0xFF432C00),
          primaryContainer: Color(0xFFFFB300),
          onPrimaryContainer: Color(0xFF3D2C00),
          secondary: Color(0xFF4ADE80),
          onSecondary: Color(0xFF003912),
          error: Color(0xFFFFB4AB),
          onError: Color(0xFF690005),
          errorContainer: Color(0xFF93000A),
          onErrorContainer: Color(0xFFFFDAD6),
          surface: Color(0xFF101114),
          onSurface: Color(0xFFE9EAEC),
          surfaceVariant: Color(0xFF2E3036),
          onSurfaceVariant: Color(0xFFA9ACB4),
          outline: Color(0xFF7E828C),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF24262B),
          contentTextStyle: const TextStyle(
              color: Color(0xFFE9EAEC), fontSize: 13),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          actionTextColor: const Color(0xFFFFD79B),
        ),
        // Consistent press behavior + shape for every stock button
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            overlayColor: WidgetStatePropertyAll(
                Colors.black.withOpacity(0.08)),
            animationDuration: const Duration(milliseconds: 120),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            overlayColor: WidgetStatePropertyAll(
                Colors.white.withOpacity(0.05)),
            animationDuration: const Duration(milliseconds: 120),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
            overlayColor: WidgetStatePropertyAll(
                Colors.white.withOpacity(0.06)),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Color(0xFFE9EAEC)),
          titleMedium: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE9EAEC)),
          bodyMedium: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFFE9EAEC)),
          labelLarge: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: Color(0xFFE9EAEC)),
          labelSmall: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE9EAEC)),
        ),
      ),
      home: _isDesktop
          ? _PhoneFrame(child: AuthGate(firebaseError: firebaseError))
          : AuthGate(firebaseError: firebaseError),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Center(
        child: Container(
          width: 393,
          height: 852,
          decoration: BoxDecoration(
            color: const Color(0xFF101114),
            borderRadius: BorderRadius.circular(44),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 60,
                spreadRadius: 20,
              ),
              BoxShadow(
                color: const Color(0xFFFFD79B).withOpacity(0.04),
                blurRadius: 100,
                spreadRadius: 10,
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: child,
        ),
      ),
    );
  }
}
