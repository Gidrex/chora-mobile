// Ratchet for `.agents/architecture.md`: new code must obey the rules, legacy
// violations are listed in baselines that may only shrink. When you fix a
// legacy file, delete its baseline entry (the test fails on stale entries).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Only these paths may touch the Rust bridge, `Backend` or `dart:io`.
const _ioLayers = ['lib/backend.dart', 'lib/data/', 'lib/platform/'];

const _ioBaseline = {
  'lib/main.dart',
  'lib/notifications.dart',
  'lib/screens/capture.dart',
  'lib/screens/events.dart',
  'lib/screens/notes.dart',
  'lib/screens/settings.dart',
};

const _maxLines = 300;

/// Legacy files over [_maxLines]: current length is the cap, lower it as you split.
const _lengthBaseline = {
  'lib/screens/events.dart': 1390,
  'lib/screens/capture.dart': 627,
  'lib/screens/settings.dart': 475,
  'lib/screens/notes.dart': 458,
};

const _emptyCatchBaseline = {'lib/screens/settings.dart'};

const _globalStateKeyBaseline = {'lib/main.dart'};

final _ioImport = RegExp(
  r'''^import '(dart:io|[^']*src/rust/[^']*|[^']*backend\.dart)';''',
  multiLine: true,
);
final _emptyCatch = RegExp(r'catch \([^)]*\) \{\s*\}');
final _rawColor = RegExp(r'Color\(0x|Colors\.(?!transparent\b)');
final _globalStateKey = RegExp(r'GlobalKey<\w+State>');

List<File> _sources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.startsWith('lib/src/rust/'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

/// Fails on new violations and on baseline entries that no longer violate.
void _ratchet(String rule, Set<String> violating, Set<String> baseline) {
  final added = violating.difference(baseline);
  final stale = baseline.difference(violating);
  expect(
    added,
    isEmpty,
    reason: '$rule: new violations, see .agents/architecture.md',
  );
  expect(stale, isEmpty, reason: '$rule: fixed, delete these baseline entries');
}

void main() {
  final files = _sources();
  String text(File f) => f.readAsStringSync();

  test('bridge, Backend and dart:io stay in data/platform layers', () {
    _ratchet('io-layer', {
      for (final f in files)
        if (!_ioLayers.any(f.path.startsWith) && _ioImport.hasMatch(text(f)))
          f.path,
    }, _ioBaseline);
  });

  test('files stay under $_maxLines lines', () {
    final over = {for (final f in files) f.path: text(f).split('\n').length - 1}
      ..removeWhere((_, lines) => lines <= _maxLines);
    _ratchet('file-length', over.keys.toSet(), _lengthBaseline.keys.toSet());
    for (final MapEntry(key: path, value: cap) in _lengthBaseline.entries) {
      expect(over[path], lessThanOrEqualTo(cap), reason: '$path grew');
    }
  });

  test('no empty catch blocks', () {
    _ratchet('empty-catch', {
      for (final f in files)
        if (_emptyCatch.hasMatch(text(f))) f.path,
    }, _emptyCatchBaseline);
  });

  test('colors come from the theme only', () {
    _ratchet('raw-color', {
      for (final f in files)
        if (f.path != 'lib/theme.dart' && _rawColor.hasMatch(text(f))) f.path,
    }, const {});
  });

  test('no cross-widget calls through GlobalKey<State>', () {
    _ratchet('global-state-key', {
      for (final f in files)
        if (_globalStateKey.hasMatch(text(f))) f.path,
    }, _globalStateKeyBaseline);
  });
}
