import 'package:chora_mobile/app/app.dart';
import 'package:chora_mobile/app/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_backend.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('back on another tab returns to Capture without a dialog', (
    tester,
  ) async {
    final services = (await tester.runAsync<AppServices>(testServices))!;
    await tester.pumpWidget(ChoraApp(services: services));
    await settle(tester);

    await tester.tap(find.text('Notes'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.text('Discard draft?'), findsNothing);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);

    // With a real draft, back on Capture itself still asks.
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'unsaved idea',
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Discard draft?'), findsOneWidget);
  });
}
