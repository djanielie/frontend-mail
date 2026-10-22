import 'package:flutter/material.dart';

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
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const ['system-ui', 'Arial'],
  );
  final text = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: dark ? ibeLuckyInk : scheme.onSurface,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: dark ? ibeLuckyInk : scheme.onSurface,
    ),
  );

  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface.withValues(alpha: dark ? 0.72 : 0.78),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: scheme.surface.withValues(alpha: dark ? 0.78 : 0.86),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xCC12182A) : Colors.white.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 3,
      focusElevation: 4,
      hoverElevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
