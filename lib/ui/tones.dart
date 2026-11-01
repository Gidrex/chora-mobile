import 'dart:math';

import 'package:flutter/material.dart';

/// Semantic text colors: every kind of text has its own tone, in every
/// preset. Ambient Night uses its pastels; the other presets derive the
/// same roles from their accent set, so widgets color alike everywhere.
@immutable
class Tones extends ThemeExtension<Tones> {
  const Tones({
    required this.file,
    required this.heading,
    required this.folder,
    required this.time,
    required this.duration,
    required this.section,
    required this.weekly,
    required this.muted,
  });

  /// Six accents in role order: time, file, duration, weekly/folder,
  /// heading, section. Mid-tone accents are lifted (dark) or deepened
  /// (light) so text stays readable on the surface (>= 4.5:1).
  factory Tones.fromAccents(List<Color> a, ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    Color legible(Color c) {
      final hsl = HSLColor.fromColor(c);
      final l = dark ? max(hsl.lightness, 0.72) : min(hsl.lightness, 0.40);
      return hsl.withLightness(l).toColor();
    }

    return Tones(
      time: legible(a[0]),
      file: legible(a[1]),
      duration: legible(a[2]),
      folder: legible(a[3]),
      weekly: legible(a[3]),
      heading: legible(a[4]),
      section: legible(a[5]),
      muted: scheme.onSurfaceVariant,
    );
  }

  /// File names and note paths.
  final Color file;

  /// Note titles (h1) and markdown headings.
  final Color heading;

  /// Project and folder names.
  final Color folder;

  /// Event start times.
  final Color time;

  /// Durations and counts.
  final Color duration;

  /// `#` sections and tags.
  final Color section;

  /// Weekly (repeating) events.
  final Color weekly;

  /// Secondary metadata.
  final Color muted;

  static Tones of(BuildContext context) {
    final tones = Theme.of(context).extension<Tones>();
    assert(tones != null, 'buildTheme registers Tones');
    return tones!;
  }

  @override
  Tones copyWith() => this;

  @override
  Tones lerp(ThemeExtension<Tones>? other, double t) {
    if (other is! Tones) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return Tones(
      file: mix(file, other.file),
      heading: mix(heading, other.heading),
      folder: mix(folder, other.folder),
      time: mix(time, other.time),
      duration: mix(duration, other.duration),
      section: mix(section, other.section),
      weekly: mix(weekly, other.weekly),
      muted: mix(muted, other.muted),
    );
  }
}
