import 'package:chora_mobile/app_state.dart';
import 'package:chora_mobile/screens/events.dart';
import 'package:chora_mobile/src/rust/api.dart';
import 'package:chora_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('calendar grid fits phone width without overflow', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    final cells = [
      for (var i = 0; i < 42; i++)
        CalendarCellDto(
          dateIso: '2026-10-${((i % 30) + 1).toString().padLeft(2, '0')}',
          dayNum: (i % 30) + 1,
          inCurrentMonth: i >= 7 && i < 35,
          dayTitle: i == 20 ? 'Standup' : null,
          repeatTitle: i % 7 == 0 ? 'Gym' : null,
        ),
    ];
    tester.view.physicalSize = const Size(1080, 2392);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          preset: 'system',
          brightness: Brightness.dark,
          fontName: 'Onest',
          dynamicScheme: null,
        ),
        home: Scaffold(
          body: CalendarGridWidget(
            cells: cells,
            square: false,
            onChanged: () {},
            state: state,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
