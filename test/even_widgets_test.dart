import 'package:chora_mobile/theme.dart';
import 'package:chora_mobile/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildTheme(
      preset: 'system',
      brightness: Brightness.dark,
      fontName: 'Onest',
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('SectionCard renders title and divided rows', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SectionCard(
          title: 'Appearance',
          children: [Text('a'), Text('b')],
        ),
      ),
    );
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('PillButton is disabled while onPressed is null', (tester) async {
    await tester.pumpWidget(
      _wrap(const PillButton.primary(label: 'Save', onPressed: null)),
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.enabled, isFalse);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('SwitchRow toggles on row tap', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _wrap(
        SwitchRow(
          icon: Icons.grid_view,
          title: 'Square cells',
          value: value,
          onChanged: (v) => value = v,
        ),
      ),
    );
    await tester.tap(find.text('Square cells'));
    expect(value, isTrue);
  });
}
