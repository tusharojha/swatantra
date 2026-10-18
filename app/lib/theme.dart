import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Rangoli palette sampled from assets/logo.png:
/// magenta petals #DC2460, teal leaves #089C9C, saffron #F47C20.
/// Newspaper restyle: pure white paper, black ink, grey secondary,
/// magenta only as kicker / link / tip accent. Square corners.
class Swa {
  static const magenta = Color(0xFFDC2460);
  static const teal = Color(0xFF089C9C);
  static const saffron = Color(0xFFF47C20);
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF5C5C5C);
  static const paper = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFD0D0D0);
  static const wash = Color(0xFFF7F7F7);

  static const pagePadding = EdgeInsets.fromLTRB(16, 8, 16, 40);
  static const maxWidth = 760.0;

  static String get _serifFallback =>
      GoogleFonts.notoSerifDevanagari().fontFamily ?? 'Noto Serif Devanagari';

  static TextStyle playfair({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color color = ink,
    double height = 1.15,
    FontStyle style = FontStyle.normal,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      fontStyle: style,
    );
  }

  static TextStyle serif({
    double size = 16,
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double height = 1.55,
  }) {
    return GoogleFonts.sourceSerif4(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    ).copyWith(fontFamilyFallback: [_serifFallback]);
  }

  static TextStyle condensed({
    double size = 12,
    FontWeight weight = FontWeight.w600,
    Color color = muted,
    double spacing = 1.2,
    double height = 1.3,
  }) {
    return GoogleFonts.robotoCondensed(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
    );
  }

  static TextStyle get kicker => condensed(
        size: 11,
        weight: FontWeight.w700,
        color: magenta,
        spacing: 1.6,
        height: 1.2,
      );

  static TextStyle get byline => condensed(
        size: 12,
        weight: FontWeight.w500,
        color: muted,
        spacing: 0.4,
        height: 1.3,
      );

  static TextStyle get dateline => condensed(
        size: 11,
        weight: FontWeight.w600,
        color: ink,
        spacing: 1.4,
        height: 1.3,
      );
}

ThemeData swatantraTheme() {
  final display = GoogleFonts.playfairDisplayTextTheme();
  final body = GoogleFonts.sourceSerif4TextTheme();
  final labels = GoogleFonts.robotoCondensedTextTheme();
  final square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
  const hairline = BorderSide(color: Swa.line);

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Swa.paper,
    canvasColor: Swa.paper,
    splashFactory: NoSplash.splashFactory,
    colorScheme: const ColorScheme.light(
      primary: Swa.magenta,
      secondary: Swa.ink,
      tertiary: Swa.magenta,
      surface: Swa.paper,
      onPrimary: Colors.white,
      onSurface: Swa.ink,
      outline: Swa.line,
    ),
    textTheme: body.copyWith(
      displayLarge: display.displayLarge?.copyWith(color: Swa.ink, fontWeight: FontWeight.w700),
      displayMedium: display.displayMedium?.copyWith(color: Swa.ink, fontWeight: FontWeight.w700),
      headlineLarge: Swa.playfair(size: 36, weight: FontWeight.w700),
      headlineMedium: Swa.playfair(size: 28, weight: FontWeight.w700),
      headlineSmall: Swa.playfair(size: 22, weight: FontWeight.w700),
      titleLarge: Swa.playfair(size: 20, weight: FontWeight.w700),
      titleMedium: Swa.playfair(size: 17, weight: FontWeight.w700, height: 1.25),
      titleSmall: Swa.playfair(size: 15, weight: FontWeight.w600),
      bodyLarge: Swa.serif(size: 17, height: 1.55),
      bodyMedium: Swa.serif(size: 15, height: 1.5),
      bodySmall: Swa.serif(size: 13, color: Swa.muted, height: 1.45),
      labelLarge: labels.labelLarge?.copyWith(
        color: Swa.ink,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
      labelMedium: Swa.dateline,
      labelSmall: Swa.kicker,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Swa.paper,
      foregroundColor: Swa.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Swa.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: hairline),
      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: hairline),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Swa.ink, width: 1.2),
      ),
      labelStyle: Swa.condensed(size: 13, color: Swa.muted, spacing: 0.6),
      hintStyle: Swa.condensed(size: 13, color: Swa.muted, spacing: 0.2, weight: FontWeight.w400),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Swa.magenta,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: square,
        textStyle: Swa.condensed(size: 13, weight: FontWeight.w700, color: Colors.white, spacing: 1.0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Swa.ink,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: hairline,
        shape: square,
        textStyle: Swa.condensed(size: 13, weight: FontWeight.w600, color: Swa.ink, spacing: 0.8),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Swa.magenta,
        shape: square,
        textStyle: Swa.condensed(size: 13, weight: FontWeight.w600, color: Swa.magenta, spacing: 0.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Swa.paper,
      elevation: 0,
      height: 64,
      indicatorColor: Colors.transparent,
      indicatorShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return Swa.condensed(
          size: 11,
          weight: FontWeight.w700,
          spacing: 1.2,
          color: selected ? Swa.magenta : Swa.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(size: 22, color: selected ? Swa.ink : Swa.muted);
      }),
    ),
    dividerColor: Swa.line,
    dividerTheme: const DividerThemeData(color: Swa.line, thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Swa.ink),
    dropdownMenuTheme: const DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: hairline),
      ),
    ),
  );
}
