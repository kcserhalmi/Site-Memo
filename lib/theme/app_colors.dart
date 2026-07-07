import 'package:flutter/material.dart';

/// Site Memo palette — deep neutral surfaces with a warm amber brand accent.
/// Neutrals are kept clean (no beige cast) so photos read true; amber is
/// reserved for actions and highlights, coral for flags/errors.
class AppColors {
  // Surfaces (cool near-black ramp)
  static const Color surface = Color(0xFF101114);
  static const Color surfaceContainerLow = Color(0xFF17181C);
  static const Color surfaceContainer = Color(0xFF1C1E22);
  static const Color surfaceContainerHigh = Color(0xFF24262B);
  static const Color surfaceContainerHighest = Color(0xFF2E3036);

  // Text & lines
  static const Color onSurface = Color(0xFFE9EAEC);
  static const Color onSurfaceVariant = Color(0xFFA9ACB4);
  static const Color outline = Color(0xFF7E828C);
  static const Color outlineVariant = Color(0xFF33363C);

  // Brand amber
  static const Color primary = Color(0xFFFFD79B);
  static const Color onPrimary = Color(0xFF432C00);
  static const Color primaryContainer = Color(0xFFFFB300);
  static const Color onPrimaryContainer = Color(0xFF3D2C00);
  static const Color primaryFixedDim = Color(0xFFFFBA38);

  // Success green
  static const Color secondary = Color(0xFF4ADE80);
  static const Color onSecondary = Color(0xFF003912);

  // Errors
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // Flag / attention coral (readable on dark surfaces)
  static const Color tertiaryContainer = Color(0xFFFFACA7);
  static const Color onTertiaryContainer = Color(0xFFFF7A70);

  static const Color background = Color(0xFF101114);
  static const Color onBackground = Color(0xFFE9EAEC);
}
