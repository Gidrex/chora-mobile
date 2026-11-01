import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/domain/dates.dart';
import 'package:chora_mobile/features/events/widgets/month_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../capture/themed.dart';

/// T1.3: a today cell with both dots fits 320 dp and 1080 dp at text scale
/// 1.3, and the weekday header renders.
void main() {
  final first = DateTime(2026, 11, 1);
  final cells = [
    for (var i = 0; i < 42; i++)
      CalendarCellDto(
        dateIso: isoOf(addDays(first, i)),
        day: addDays(first, i).day,
        inMonth: i < 30,
        dayTitle: 'Standup',
        repeatTitle: 'Gym',
      ),
  ];

  for (final width in [320.0, 1080.0]) {
    for (final square in [false, true]) {
      testWidgets('grid fits ${width}dp square=$square', (tester) async {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        DateTime? tapped;
        await tester.pumpWidget(
          MaterialApp(
            theme: appTheme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const WeekdayHeader(),
                      MonthGrid(
                        cells: cells,
                        today: first,
                        selected: DateTime(2026, 11, 2),
                        square: square,
                        onSelect: (d) => tapped = d,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('S'), findsNWidgets(2));
        expect(find.byType(DayCell), findsNWidgets(42));
        await tester.tap(find.text('5').first);
        expect(tapped, DateTime(2026, 11, 5));
        final today = tester.getSemantics(find.byType(DayCell).first);
        expect(today.label, contains('today'));
      });
    }
  }
}
