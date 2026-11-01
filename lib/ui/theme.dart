import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palettes.dart';
import 'theme_helpers.dart';
import 'tones.dart';

/// Cache key for preset-built themes (dynamic schemes bypass the cache:
/// [DynamicColorBuilder] hands out a fresh scheme object per build).
({String preset, Brightness brightness, String fontName}) _cacheKey(
  String preset,
  Brightness brightness,
  String fontName,
) => (preset: preset, brightness: brightness, fontName: fontName);

final _themeCache =
    <({String preset, Brightness brightness, String fontName}), ThemeData>{};

/// Preset color schemes. `system` is resolved from [DynamicColorBuilder].
ThemeData buildTheme({
  required String preset,
  required Brightness brightness,
  required String fontName,
  ColorScheme? dynamicScheme,
}) {
  // A fixed preset ignores the dynamic scheme, so it is always cacheable.
  if (dynamicScheme == null || preset != 'system') {
    return _themeCache.putIfAbsent(
      _cacheKey(preset, brightness, fontName),
      () => _buildTheme(
        preset: preset,
        brightness: brightness,
        fontName: fontName,
        dynamicScheme: dynamicScheme,
      ),
    );
  }
  return _buildTheme(
    preset: preset,
    brightness: brightness,
    fontName: fontName,
    dynamicScheme: dynamicScheme,
  );
}

ThemeData _buildTheme({
  required String preset,
  required Brightness brightness,
  required String fontName,
  ColorScheme? dynamicScheme,
}) {
  final dark = brightness == Brightness.dark;
  final scheme =
      presetScheme(preset, brightness) ??
      dynamicScheme ??
      ColorScheme.fromSeed(seedColor: Colors.teal, brightness: brightness);

  // Explicit brightness-matching base: GoogleFonts.*TextTheme() without an
  // argument bakes in light (black) text colors, unreadable on dark surfaces.
  final TextTheme fallback =
      (dark ? ThemeData.dark() : ThemeData.light()).textTheme;
  // Bundled offline families (assets/fonts, no runtime fetching).
  const families = {'Onest', 'Golos Text', 'Martian Mono', 'IBM Plex Mono'};
  final TextTheme base = fallback.apply(
    fontFamily: families.contains(fontName) ? fontName : 'Onest',
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  final accents = presetAccents(preset, brightness, scheme);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: base,
    scaffoldBackgroundColor: scheme.surface,
    extensions: <ThemeExtension<dynamic>>[
      EventPalette(accents),
      Tones.fromAccents(accents, scheme),
    ],
    // Soft night-sky surfaces: borderless rounded cards with a faint shadow.
    cardTheme: CardThemeData(
      elevation: dark ? 2 : 1,
      shadowColor: scheme.shadow.withValues(alpha: dark ? 0.6 : 0.15),
      color: scheme.surfaceContainer,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      iconColor: scheme.onSurfaceVariant,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      elevation: 0,
    ),
    appBarTheme: AppBarTheme(
      // Status bar icons must contrast with the surface (dark icons on light).
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
    ),
    sliderTheme: SliderThemeData(
      showValueIndicator: ShowValueIndicator.onDrag,
      inactiveTrackColor: scheme.surfaceContainerHighest,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
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
