// Mechanical rules from `.agents/architecture.md`. There are no baselines:
// every rule holds for every file.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Only these paths may touch the Rust bridge or `dart:io`.
const _ioLayers = ['lib/data/', 'lib/platform/', 'lib/main.dart'];

const _maxLines = 300;

/// The only files that may spell out colors.
const _colorFiles = {'lib/ui/theme.dart', 'lib/ui/palettes.dart'};

final _ioImport = RegExp(
  r'''^import '(dart:io|[^']*src/rust/[^']*)';''',
  multiLine: true,
);
final _flutterImport = RegExp(r"^import 'package:flutter/", multiLine: true);
final _featureImport = RegExp(
  r"^import '[./]*features/(\w+)/",
  multiLine: true,
);
final _emptyCatch = RegExp(r'catch \([^)]*\) \{\s*\}|on \w+ \{\s*\}');
final _rawColor = RegExp(r'\bColor\(0x|\bColors\.(?!transparent\b)');
final _globalStateKey = RegExp(r'GlobalKey<\w+State>');

List<File> _sources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.startsWith('lib/src/rust/'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  final files = {for (final f in _sources()) f.path: f.readAsStringSync()};

  Set<String> violating(bool Function(String path, String text) rule) => {
    for (final MapEntry(key: path, value: text) in files.entries)
      if (rule(path, text)) path,
  };

  test('bridge and dart:io stay in data/platform layers', () {
    expect(
      violating(
        (p, t) => !_ioLayers.any(p.startsWith) && _ioImport.hasMatch(t),
      ),
      isEmpty,
    );
  });

  test('domain is pure Dart', () {
    expect(
      violating(
        (p, t) => p.startsWith('lib/domain/') && _flutterImport.hasMatch(t),
      ),
      isEmpty,
    );
  });

  test('features import only themselves and lock', () {
    expect(
      violating((p, t) {
        final own = RegExp(r'lib/features/(\w+)/').firstMatch(p)?.group(1);
        if (own == null) return false;
        return _featureImport
            .allMatches(t)
            .map((m) => m.group(1))
            .any((f) => f != own && f != 'lock');
      }),
      isEmpty,
    );
  });

  test('files stay under $_maxLines lines', () {
    expect(violating((_, t) => t.split('\n').length - 1 > _maxLines), isEmpty);
  });

  test('no empty catch blocks', () {
    expect(violating((_, t) => _emptyCatch.hasMatch(t)), isEmpty);
  });

  test('colors come from the theme only', () {
    expect(
      violating((p, t) => !_colorFiles.contains(p) && _rawColor.hasMatch(t)),
      isEmpty,
    );
  });

  test('no cross-widget calls through GlobalKey<State>', () {
    expect(violating((_, t) => _globalStateKey.hasMatch(t)), isEmpty);
  });
}
