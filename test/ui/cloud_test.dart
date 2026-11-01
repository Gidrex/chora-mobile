import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/ui/cloud.dart';
import 'package:chora_mobile/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final preset in ThemePreset.values) {
    for (final b in Brightness.values) {
      testWidgets('cloud paints in ${preset.name} $b', (tester) async {
        final theme = buildTheme(
          preset: preset.name,
          brightness: b,
          fontName: 'Onest',
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: Column(
                children: [
                  CloudArt(),
                  SizedBox(width: 320, child: CloudArt(height: 80)),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final colors = CloudColors.of(
          tester.element(find.byType(CloudArt).first),
        );
        // The inner layer must stand out from the body.
        expect(colors.light, isNot(colors.body));
      });
    }
  }
}
