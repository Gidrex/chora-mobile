import 'package:flutter/material.dart';

// Raw preset colors live here and in theme.dart only (architecture test).

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

/// Ambient Night pastels (night sky reference): mint, sky, peach,
/// lavender, pink, moon yellow. Dark uses them as is; light uses deeper
/// shades of the same hues for contrast on paper.
const _ambientDarkAccents = [
  Color(0xFF94D9C2),
  Color(0xFF92B8F0),
  Color(0xFFF7B58C),
  Color(0xFFB6A6F0),
  Color(0xFFF2A7BE),
  Color(0xFFF3D27A),
];

const _ambientLightAccents = [
  Color(0xFF2E8A6E),
  Color(0xFF3E6DB5),
  Color(0xFFB8622E),
  Color(0xFF6A55C2),
  Color(0xFFB5476E),
  Color(0xFF8F6D12),
];

/// Six hues around the wallpaper's primary: distinct roles, one family.
List<Color> _dynamicAccents(ColorScheme s) {
  final base = HSLColor.fromColor(s.primary);
  return [
    for (var i = 0; i < 6; i++)
      base
          .withHue((base.hue + i * 60) % 360)
          .withSaturation(base.saturation < 0.45 ? 0.45 : base.saturation)
          .toColor(),
  ];
}

/// Fixed scheme of a preset, or null for `system` (dynamic or seeded).
ColorScheme? presetScheme(String preset, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (preset) {
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
    'ambient' =>
      dark
          ? const ColorScheme.dark(
              primary: Color(0xFFB6A6F0),
              onPrimary: Color(0xFF1C1D24),
              primaryContainer: Color(0xFF3A3456),
              onPrimaryContainer: Color(0xFFDCD3FF),
              secondary: Color(0xFF94D9C2),
              onSecondary: Color(0xFF1C1D24),
              secondaryContainer: Color(0xFF24403A),
              onSecondaryContainer: Color(0xFFC6F1E3),
              tertiary: Color(0xFFF7B58C),
              onTertiary: Color(0xFF1C1D24),
              tertiaryContainer: Color(0xFF4A3324),
              onTertiaryContainer: Color(0xFFFFDCC6),
              error: Color(0xFFEE8E8E),
              onError: Color(0xFF1C1D24),
              surface: Color(0xFF1C1D24),
              onSurface: Color(0xFFE4E4EC),
              onSurfaceVariant: Color(0xFF9A9BAA),
              surfaceContainerLowest: Color(0xFF18191F),
              surfaceContainerLow: Color(0xFF202129),
              surfaceContainer: Color(0xFF25262F),
              surfaceContainerHigh: Color(0xFF2C2D38),
              surfaceContainerHighest: Color(0xFF343542),
              outline: Color(0xFF5A5B6A),
              outlineVariant: Color(0xFF30313D),
            )
          : const ColorScheme.light(
              primary: Color(0xFF6A55C2),
              onPrimary: Colors.white,
              primaryContainer: Color(0xFFE6DFFF),
              onPrimaryContainer: Color(0xFF2B2160),
              secondary: Color(0xFF2E8A6E),
              onSecondary: Colors.white,
              secondaryContainer: Color(0xFFD3F2E7),
              onSecondaryContainer: Color(0xFF0E3A2D),
              tertiary: Color(0xFFB8622E),
              onTertiary: Colors.white,
              tertiaryContainer: Color(0xFFFFE2D0),
              onTertiaryContainer: Color(0xFF4A2410),
              error: Color(0xFFC0474F),
              surface: Color(0xFFF4F1F8),
              onSurface: Color(0xFF2A2833),
              onSurfaceVariant: Color(0xFF64627A),
              surfaceContainerLowest: Color(0xFFFFFFFF),
              surfaceContainerLow: Color(0xFFF9F7FC),
              surfaceContainer: Color(0xFFFFFFFF),
              surfaceContainerHigh: Color(0xFFECE8F3),
              surfaceContainerHighest: Color(0xFFE2DDEC),
              outline: Color(0xFF8E8BA3),
              outlineVariant: Color(0xFFDAD5E6),
            ),
    _ => null,
  };
}

/// Six accents per preset, in [Tones.fromAccents] role order.
List<Color> presetAccents(
  String preset,
  Brightness brightness,
  ColorScheme scheme,
) {
  final dark = brightness == Brightness.dark;
  return switch (preset) {
    'obsidian' => _obsidianAccents,
    'luma' => _lumaAccents,
    'ambient' => dark ? _ambientDarkAccents : _ambientLightAccents,
    'mono' => dark ? _monoDarkAccents : _monoLightAccents,
    _ => _dynamicAccents(scheme),
  };
}
