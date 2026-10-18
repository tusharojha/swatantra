import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Rangoli palette sampled from assets/logo.png:
/// magenta petals #DC2460, teal leaves #089C9C, saffron #F47C20.
/// Newspaper restyle: white paper, black ink, grey secondary,
/// magenta only as kicker / link / tip. Square corners.
///
/// Fonts are bundled under fonts/ so web and APK do not depend on
/// fonts.gstatic.com. google_fonts is a fallback (Devanagari + if assets fail).
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

  static const pagePadding = EdgeInsets.fromLTRB(22, 16, 22, 48);
  static const maxWidth = 1200.0;
  static const articleWidth = 720.0;
  static const desktopBreakpoint = 1024.0;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  static String get _devanagari =>
      GoogleFonts.notoSerifDevanagari().fontFamily ?? 'Noto Serif Devanagari';

  static TextStyle playfair({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color color = ink,
    double height = 1.15,
    FontStyle style = FontStyle.normal,
  }) {
    return TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontFamilyFallback: [
        GoogleFonts.playfairDisplay().fontFamily ?? 'serif',
        _devanagari,
        'serif',
      ],
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      fontStyle: style,
    );
  }

  static TextStyle serif({
    double size = 16.5,
    FontWeight weight = FontWeight.w400,
    Color color = ink,
    double height = 1.5,
  }) {
    return TextStyle(
      fontFamily: 'SourceSerif4',
      fontFamilyFallback: [
        GoogleFonts.sourceSerif4().fontFamily ?? 'serif',
        _devanagari,
        'serif',
      ],
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static TextStyle ui({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = ink,
    double spacing = 0.2,
    double height = 1.3,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: [
        GoogleFonts.inter().fontFamily ?? 'sans-serif',
        'sans-serif',
      ],
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: height,
    );
  }

  static TextStyle get kicker => ui(
        size: 12,
        weight: FontWeight.w700,
        color: magenta,
        spacing: 1.4,
        height: 1.2,
      );

  static TextStyle get byline => ui(
        size: 13,
        weight: FontWeight.w500,
        color: muted,
        spacing: 0.1,
        height: 1.35,
      );

  static TextStyle get dateline => ui(
        size: 12,
        weight: FontWeight.w600,
        color: ink,
        spacing: 0.8,
        height: 1.3,
      );

  static TextStyle get demoLine => ui(
        size: 12,
        weight: FontWeight.w400,
        color: muted,
        spacing: 0.1,
        height: 1.35,
      );
}

class PageWidth extends StatelessWidget {
  final Widget child;
  final double max;
  const PageWidth({super.key, required this.child, this.max = Swa.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: child,
      ),
    );
  }
}

ThemeData swatantraTheme() {
  final square = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
  const hairline = BorderSide(color: Swa.line);
  const tap = Size(48, 48);

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
    textTheme: TextTheme(
      displayLarge: Swa.playfair(size: 44, weight: FontWeight.w700),
      displayMedium: Swa.playfair(size: 36, weight: FontWeight.w700),
      headlineLarge: Swa.playfair(size: 36, weight: FontWeight.w700),
      headlineMedium: Swa.playfair(size: 30, weight: FontWeight.w700, height: 1.12),
      headlineSmall: Swa.playfair(size: 24, weight: FontWeight.w700, height: 1.18),
      titleLarge: Swa.playfair(size: 22, weight: FontWeight.w700, height: 1.2),
      titleMedium: Swa.playfair(size: 18, weight: FontWeight.w700, height: 1.25),
      titleSmall: Swa.playfair(size: 16, weight: FontWeight.w600, height: 1.25),
      bodyLarge: Swa.serif(size: 17, height: 1.5),
      bodyMedium: Swa.serif(size: 16.5, height: 1.5),
      bodySmall: Swa.serif(size: 14, color: Swa.muted, height: 1.45),
      labelLarge: Swa.ui(size: 13, weight: FontWeight.w600, spacing: 0.4),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: hairline),
      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: hairline),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Swa.ink, width: 1.2),
      ),
      labelStyle: Swa.ui(size: 13, color: Swa.muted, spacing: 0.2),
      hintStyle: Swa.ui(size: 13, color: Swa.muted, weight: FontWeight.w400),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Swa.magenta,
        foregroundColor: Colors.white,
        minimumSize: tap,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: square,
        textStyle: Swa.ui(size: 14, weight: FontWeight.w700, color: Colors.white, spacing: 0.4),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Swa.ink,
        minimumSize: tap,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: hairline,
        shape: square,
        textStyle: Swa.ui(size: 14, weight: FontWeight.w600, color: Swa.ink, spacing: 0.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Swa.magenta,
        minimumSize: const Size(44, 44),
        shape: square,
        textStyle: Swa.ui(size: 14, weight: FontWeight.w600, color: Swa.magenta, spacing: 0.2),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Swa.paper,
      elevation: 0,
      height: 68,
      indicatorColor: Colors.transparent,
      indicatorShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return Swa.ui(
          size: 11,
          weight: FontWeight.w700,
          spacing: 0.6,
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
    chipTheme: ChipThemeData(
      backgroundColor: Swa.paper,
      selectedColor: Swa.paper,
      side: BorderSide.none,
      labelStyle: Swa.ui(size: 13, weight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
  );
}
