import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Per-preset accent set for event capsules (borders, dots, glows).
/// The only non-scheme colors in the UI; everything reads them from here.
@immutable
class EventPalette extends ThemeExtension<EventPalette> {
  const EventPalette(this.accents);

  final List<Color> accents;

  @override
  EventPalette copyWith({List<Color>? accents}) =>
      EventPalette(accents ?? this.accents);

  @override
  EventPalette lerp(ThemeExtension<EventPalette>? other, double t) {
    if (other is! EventPalette || other.accents.length != accents.length) {
      return this;
    }
    return EventPalette([
      for (var i = 0; i < accents.length; i++)
        Color.lerp(accents[i], other.accents[i], t)!,
    ]);
  }
}

/// Mid-tone accents readable on both light and dark surfaces.
const _obsidianAccents = [
  Color(0xFF65A30D),
  Color(0xFF0D9488),
  Color(0xFFEA580C),
  Color(0xFF9333EA),
  Color(0xFFDB2777),
  Color(0xFF2563EB),
];

const _lumaAccents = [
  Color(0xFFC2410C),
  Color(0xFF4D7C0F),
  Color(0xFF0F766E),
  Color(0xFF7C3AED),
  Color(0xFFBE185D),
  Color(0xFF1D4ED8),
];

const _monoDarkAccents = [
  Color(0xFFFFFFFF),
  Color(0xFFE8E8E8),
  Color(0xFFD1D1D1),
  Color(0xFFB8B8B8),
  Color(0xFFA0A0A0),
  Color(0xFF8F8F8F),
];

const _monoLightAccents = [
  Color(0xFF111111),
  Color(0xFF2B2B2B),
  Color(0xFF444444),
  Color(0xFF5C5C5C),
  Color(0xFF737373),
  Color(0xFF8A8A8A),
];

List<Color> _dynamicAccents(ColorScheme s) {
  Color shift(Color c, double by) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + by).clamp(0.0, 1.0)).toColor();
  }

  return [
    s.primary,
    s.secondary,
    s.tertiary,
    s.error,
    shift(s.primary, -0.12),
    shift(s.secondary, 0.12),
  ];
}

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

  // Explicit brightness-matching base: GoogleFonts.*TextTheme() without an
  // argument bakes in light (black) text colors, unreadable on dark surfaces.
  final TextTheme fallback =
      (dark ? ThemeData.dark() : ThemeData.light()).textTheme;
  final TextTheme base = switch (fontName) {
    'Golos Text' => GoogleFonts.golosTextTextTheme(fallback),
    'Martian Mono' => GoogleFonts.martianMonoTextTheme(fallback),
    'IBM Plex Mono' => GoogleFonts.ibmPlexMonoTextTheme(fallback),
    _ => GoogleFonts.onestTextTheme(fallback),
  };

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: base,
    scaffoldBackgroundColor: scheme.surface,
    extensions: <ThemeExtension<dynamic>>[
      EventPalette(switch (preset) {
        'obsidian' => _obsidianAccents,
        'luma' => _lumaAccents,
        'mono' => dark ? _monoDarkAccents : _monoLightAccents,
        _ => _dynamicAccents(scheme),
      }),
    ],
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
Widget badge(
  BuildContext context,
  String text, {
  Color? color,
  Widget? leading,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color ?? scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 2)],
        Text(text, style: mono(context, size: 11)),
      ],
    ),
  );
}

/// Security badge color: open neutral, restricted tertiary, critical error.
Widget securityBadge(BuildContext context, String level) {
  final scheme = Theme.of(context).colorScheme;
  final Color? color = switch (level) {
    'restricted' => scheme.tertiary.withValues(alpha: 0.25),
    'critical' => scheme.error.withValues(alpha: 0.25),
    _ => null,
  };
  return badge(
    context,
    '[$level]',
    color: color,
    leading: level == 'critical' ? const Icon(Icons.lock, size: 11) : null,
  );
}
