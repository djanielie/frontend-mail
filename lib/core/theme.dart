import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const ibeLuckyBlue = Color(0xFF4B66D8);
const ibeLuckyBlueBright = Color(0xFF7B93FF);
const ibeLuckyVoid = Color(0xFF060910);
const ibeLuckyInk = Color(0xFFF8FAFC);

ThemeData buildMailTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: ibeLuckyBlue,
    brightness: brightness,
  ).copyWith(
    primary: dark ? ibeLuckyBlueBright : ibeLuckyBlue,
    surface: dark ? ibeLuckyVoid : const Color(0xFFF7F8FC),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    visualDensity: VisualDensity.standard,
  );
  final text = GoogleFonts.figtreeTextTheme(base.textTheme).copyWith(
    headlineMedium: GoogleFonts.sora(
      textStyle: base.textTheme.headlineMedium,
      fontWeight: FontWeight.w600,
      color: dark ? ibeLuckyInk : scheme.onSurface,
    ),
    titleLarge: GoogleFonts.sora(
      textStyle: base.textTheme.titleLarge,
      fontWeight: FontWeight.w600,
      color: dark ? ibeLuckyInk : scheme.onSurface,
    ),
  );

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF12182A) : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ibeLuckyBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1A2238) : scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.45)),
  );
}
