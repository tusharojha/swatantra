import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Rangoli palette taken from assets/logo.png — one accent (magenta),
/// teal for proof, saffron for support.
class Swa {
  static const magenta = Color(0xFFE11D74);
  static const teal = Color(0xFF0D9488);
  static const saffron = Color(0xFFF97316);
  static const ink = Color(0xFF1C1917);
  static const muted = Color(0xFF78716C);
  static const paper = Color(0xFFFFFBFA);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE7E5E4);
  static const wash = Color(0xFFF5F5F4);
}

ThemeData swatantraTheme() {
  final display = GoogleFonts.frauncesTextTheme();
  final body = GoogleFonts.sourceSans3TextTheme();
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Swa.paper,
    colorScheme: const ColorScheme.light(
      primary: Swa.magenta,
      secondary: Swa.teal,
      tertiary: Swa.saffron,
      surface: Swa.paper,
      onPrimary: Colors.white,
      onSurface: Swa.ink,
    ),
    textTheme: body.copyWith(
      displayLarge: display.displayLarge?.copyWith(color: Swa.ink, fontWeight: FontWeight.w600),
      displayMedium: display.displayMedium?.copyWith(color: Swa.ink, fontWeight: FontWeight.w600),
      headlineLarge: display.headlineLarge?.copyWith(color: Swa.ink, fontWeight: FontWeight.w600, fontSize: 32),
      headlineMedium: display.headlineMedium?.copyWith(color: Swa.ink, fontWeight: FontWeight.w600, fontSize: 24),
      headlineSmall: display.headlineSmall?.copyWith(color: Swa.ink, fontWeight: FontWeight.w600, fontSize: 20),
      titleLarge: display.titleLarge?.copyWith(color: Swa.ink, fontWeight: FontWeight.w600),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Swa.paper,
      foregroundColor: Swa.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Swa.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Swa.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Swa.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Swa.magenta, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Swa.magenta,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Swa.ink,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: Swa.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Swa.card,
      indicatorColor: Color(0x1FE11D74),
      elevation: 0,
    ),
    dividerColor: Swa.line,
  );
}
