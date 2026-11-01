import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/domain/dates.dart';
import 'package:chora_mobile/features/events/events_controller.dart';
import 'package:chora_mobile/features/events/events_screen.dart';
import 'package:chora_mobile/features/events/widgets/event_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_backend.dart';
import 'fake_events_repository.dart';
import '../capture/themed.dart';

/// Let chained bridge calls finish: each hop needs real time, then a pump
/// to run its continuation in the test zone.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('form survives 320dp at text scale 2.0', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsStore(await SharedPreferences.getInstance());
    final controller = EventsController(
      FakeEventsRepository(),
      settings,
      ValueNotifier(0),
      afterSave: (_) async {},
      refresh: () async {},
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: EventFormPage(
            controller: controller,
            date: DateTime(2026, 11, 2),
            original: ev('Standup with a long title that wraps'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Repeats weekly'), findsOneWidget);
    final custom = find.widgetWithText(TextField, 'Custom duration');
    await tester.scrollUntilVisible(
      custom,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(custom, 'soon');
    await tester.pump();
    expect(find.text('Use minutes, 1h 15m or 1:15'), findsOneWidget);
    final save = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('create an event through the form against the real backend', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = (await tester.runAsync(testServices))!;
    await tester.pumpWidget(harness(services, const EventsScreen()));
    await settle(tester);
    expect(find.text('No events this day.'), findsOneWidget);

    await tester.tap(find.text('New event'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Dentist');
    await tester.tap(find.text('45 min'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await settle(tester);
    await tester.pumpAndSettle();

    final today = dayOf(DateTime.now());
    final saved = (await tester.runAsync(() => services.events.day(today)))!;
    expect(saved.single.title, 'Dentist');
    expect(saved.single.durationSecs, 45 * 60);
    await settle(tester);
    expect(find.text('Dentist'), findsOneWidget);
  });
}
