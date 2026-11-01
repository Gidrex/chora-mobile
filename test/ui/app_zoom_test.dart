import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/ui/app_zoom.dart';
import 'package:chora_mobile/ui/theme.dart';
import 'package:chora_mobile/ui/tones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('zoom shrinks the logical screen and scales text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late MediaQueryData inner;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            AppZoom(textScale: 1.2, uiScale: 1.25, child: child!),
        home: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            return const Scaffold(body: Text('x'));
          },
        ),
      ),
    );
    expect(inner.size, const Size(800, 1600));
    expect(inner.textScaler.scale(10), closeTo(12, 0.001));
    // The zoomed app still fills the whole screen.
    expect(
      tester.getBottomRight(find.byType(Scaffold)),
      const Offset(1000, 2000),
    );
  });

  test('every preset registers distinct text tones in both brightnesses', () {
    for (final preset in ThemePreset.values) {
      for (final b in Brightness.values) {
        final theme = buildTheme(
          preset: preset.name,
          brightness: b,
          fontName: 'Onest',
        );
        final t = theme.extension<Tones>()!;
        if (preset == ThemePreset.mono) continue; // greys by design
        expect(
          {t.file, t.heading, t.folder, t.time, t.duration, t.section}.length,
          6,
          reason: '${preset.name} $b',
        );
      }
    }
  });
}
