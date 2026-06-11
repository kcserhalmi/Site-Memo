import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/main_shell.dart';

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

  final provider = AppProvider();
  await provider.loadData();

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const SiteMemoApp(),
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
  const SiteMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Site Memo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF131313),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD79B),
          onPrimary: Color(0xFF432C00),
          primaryContainer: Color(0xFFFFB300),
          onPrimaryContainer: Color(0xFF6B4900),
          secondary: Color(0xFF40E56C),
          onSecondary: Color(0xFF003912),
          error: Color(0xFFFFB4AB),
          onError: Color(0xFF690005),
          errorContainer: Color(0xFF93000A),
          onErrorContainer: Color(0xFFFFDAD6),
          surface: Color(0xFF131313),
          onSurface: Color(0xFFE5E2E1),
          surfaceVariant: Color(0xFF353534),
          onSurfaceVariant: Color(0xFFD6C4AC),
          outline: Color(0xFF9E8E78),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Color(0xFFE5E2E1)),
          titleMedium: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE5E2E1)),
          bodyMedium: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFFE5E2E1)),
          labelLarge: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: Color(0xFFE5E2E1)),
          labelSmall: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE5E2E1)),
        ),
      ),
      home: _isDesktop
          ? const _PhoneFrame(child: MainShell())
          : const MainShell(),
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
            color: const Color(0xFF131313),
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
