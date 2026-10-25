import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Preset color schemes. `system` is resolved from [DynamicColorBuilder].
ThemeData buildTheme({
  required String preset,
  required Brightness brightness,
  required String fontName,
  ColorScheme? dynamicScheme,
}) {
  final dark = brightness == Brightness.dark;
  final ColorScheme scheme = switch (preset) {
    'obsidian' =>
      dark
          ? const ColorScheme.dark(
              primary: Color(0xFFA3FF12),
              onPrimary: Color(0xFF090A0C),
              primaryContainer: Color(0xFF2A3311),
              onPrimaryContainer: Color(0xFFA3FF12),
              secondary: Color(0xFFA3FF12),
              onSecondary: Color(0xFF090A0C),
              secondaryContainer: Color(0xFF2A3311),
              onSecondaryContainer: Color(0xFFD4FF7A),
              surface: Color(0xFF090A0C),
              surfaceContainer: Color(0xFF121418),
              surfaceContainerHigh: Color(0xFF1A1E24),
              surfaceContainerHighest: Color(0xFF22262E),
              outlineVariant: Color(0xFF22262E),
            )
          : const ColorScheme.light(
              primary: Color(0xFF4A7A00),
              onPrimary: Colors.white,
              primaryContainer: Color(0xFFDDF0A8),
              onPrimaryContainer: Color(0xFF2A4400),
              secondary: Color(0xFF4A7A00),
              onSecondary: Colors.white,
              secondaryContainer: Color(0xFFDDF0A8),
              onSecondaryContainer: Color(0xFF2A4400),
              surface: Color(0xFFF4F6EC),
              surfaceContainer: Color(0xFFFFFFFF),
              surfaceContainerHigh: Color(0xFFEDEFE2),
              surfaceContainerHighest: Color(0xFFE2E5D3),
            ),
    'luma' =>
      dark
          ? const ColorScheme.dark(
              primary: Color(0xFFFF6B4A),
              onPrimary: Color(0xFF141312),
              primaryContainer: Color(0xFF4A2318),
              onPrimaryContainer: Color(0xFFFFB59D),
              secondary: Color(0xFFFF6B4A),
              onSecondary: Color(0xFF141312),
              secondaryContainer: Color(0xFF4A2318),
              onSecondaryContainer: Color(0xFFFFB59D),
              surface: Color(0xFF141312),
              surfaceContainer: Color(0xFF1E1C1A),
              surfaceContainerHigh: Color(0xFF282522),
              surfaceContainerHighest: Color(0xFF35302B),
              outlineVariant: Color(0xFF3A352F),
            )
          : const ColorScheme.light(
              primary: Color(0xFFC74A2E),
              onPrimary: Colors.white,
              primaryContainer: Color(0xFFFFDAD0),
              onPrimaryContainer: Color(0xFF5C1A0C),
              secondary: Color(0xFFC74A2E),
              onSecondary: Colors.white,
              secondaryContainer: Color(0xFFFFDAD0),
              onSecondaryContainer: Color(0xFF5C1A0C),
              surface: Color(0xFFFAF8F5),
              surfaceContainer: Color(0xFFFFFFFF),
              surfaceContainerHigh: Color(0xFFF1ECE5),
              surfaceContainerHighest: Color(0xFFE6E2DC),
              outlineVariant: Color(0xFFE6E2DC),
            ),
    'mono' =>
      dark
          ? const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              primaryContainer: Color(0xFF2A2A2A),
              onPrimaryContainer: Colors.white,
              secondary: Colors.white,
              onSecondary: Colors.black,
              secondaryContainer: Color(0xFF2A2A2A),
              onSecondaryContainer: Colors.white,
              surface: Colors.black,
              surfaceContainer: Color(0xFF111111),
              surfaceContainerHigh: Color(0xFF1C1C1C),
              surfaceContainerHighest: Color(0xFF2A2A2A),
              outlineVariant: Color(0xFF3A3A3A),
            )
          : const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              primaryContainer: Color(0xFF222222),
              onPrimaryContainer: Colors.white,
              secondary: Colors.black,
              onSecondary: Colors.white,
              secondaryContainer: Color(0xFFE2E2E2),
              onSecondaryContainer: Colors.black,
              surface: Colors.white,
              surfaceContainer: Colors.white,
              surfaceContainerHigh: Color(0xFFF0F0F0),
              surfaceContainerHighest: Color(0xFFE2E2E2),
              outlineVariant: Color(0xFF444444),
            ),
    _ =>
      dynamicScheme ??
          ColorScheme.fromSeed(seedColor: Colors.teal, brightness: brightness),
  };

  final TextTheme base = switch (fontName) {
    'Golos Text' => GoogleFonts.golosTextTextTheme(),
    'Martian Mono' => GoogleFonts.martianMonoTextTheme(),
    'IBM Plex Mono' => GoogleFonts.ibmPlexMonoTextTheme(),
    _ => GoogleFonts.onestTextTheme(),
  };

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: base,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
  );
}

/// Mono style for paths, levels, times and autocomplete (SPEC typography rule).
TextStyle mono(BuildContext context, {double? size}) {
  final base = Theme.of(context).textTheme.bodyMedium;
  return GoogleFonts.ibmPlexMono(textStyle: base, fontSize: size ?? 12.5);
}

/// Small metadata badge: `09:00`, `45m`, `[restricted]`.
Widget badge(BuildContext context, String text, {Color? color}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color ?? scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: mono(context, size: 11)),
  );
}

/// Security badge color: open neutral, restricted amber, critical red.
Widget securityBadge(BuildContext context, String level) {
  final Color? color = switch (level) {
    'restricted' => Colors.amber.withValues(alpha: 0.25),
    'critical' => Colors.red.withValues(alpha: 0.25),
    _ => null,
  };
  final icon = level == 'critical' ? '🔒 ' : '';
  return badge(context, '$icon[$level]', color: color);
}
