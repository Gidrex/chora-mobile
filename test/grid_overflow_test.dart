import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/data/events_repository.dart';
import 'package:chora_mobile/features/events/events_controller.dart';
import 'package:chora_mobile/features/events/widgets/calendar_grid.dart';
import 'package:chora_mobile/features/events/widgets/weekday_header.dart';
import 'package:chora_mobile/src/rust/api.dart';
import 'package:chora_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T1.3: today cell with both dots survives 320 dp and 1080 dp widths at
/// text scale 1.3, and the Sunday-first weekday header renders.
void main() {
  testWidgets('calendar grid fits phone width without overflow', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final state = SettingsStore(
      await SharedPreferences.getInstance(),
      AppearanceSettings(await SharedPreferences.getInstance()),
    );
    final today = DateTime.now();
    final todayIso =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    List<CalendarCellDto> cells() => [
      for (var i = 0; i < 42; i++)
        CalendarCellDto(
          dateIso: i == 20
              ? todayIso
              : '2026-10-${((i % 30) + 1).toString().padLeft(2, '0')}',
          dayNum: (i % 30) + 1,
          inCurrentMonth: i >= 7 && i < 35,
          dayTitle: i == 20 ? 'Standup' : null,
          repeatTitle: i == 20 || i % 7 == 0 ? 'Gym' : null,
        ),
    ];
    Widget tree() => MaterialApp(
      theme: buildTheme(
        preset: 'system',
        brightness: Brightness.dark,
        fontName: 'Onest',
        dynamicScheme: null,
      ),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: Scaffold(
          body: CalendarGrid(
            cells: cells(),
            square: false,
            controller: EventsController(BridgeEventsRepository(), state),
          ),
        ),
      ),
    );
    addTearDown(tester.view.reset);
    for (final width in [320.0, 1080.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(tree());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('weekday header shows Sunday-first narrow names', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WeekdayHeader())),
    );
    expect(find.text('S'), findsNWidgets(2));
    expect(find.text('M'), findsOneWidget);
    expect(find.text('T'), findsNWidgets(2));
    expect(find.text('W'), findsOneWidget);
    expect(find.text('F'), findsOneWidget);
  });
}
