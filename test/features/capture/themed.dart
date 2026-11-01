import 'package:chora_mobile/ui/theme.dart';
import 'package:flutter/material.dart';

/// The real app theme (with `Tones`/`EventPalette`) for tests that build a
/// bare MaterialApp instead of `harness()`.
final appTheme = buildTheme(
  preset: 'ambient',
  brightness: Brightness.dark,
  fontName: 'Onest',
);
