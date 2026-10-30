import 'package:chora_mobile/app_state.dart';
import 'package:chora_mobile/backend.dart';
import 'package:chora_mobile/features/capture/capture_screen.dart';
import 'package:chora_mobile/app/app_scope.dart';
import 'package:chora_mobile/data/capture_repository.dart';
import 'package:chora_mobile/data/events_repository.dart';
import 'package:chora_mobile/data/notes_repository.dart';
import 'package:chora_mobile/features/notes/note_viewer_screen.dart';
import 'package:chora_mobile/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_backend.dart';

Widget _wrap(Widget child, AppState state) {
  return AppScope(
    state: state,
    notes: BridgeNotesRepository(),
    capture: CaptureRepository(),
    events: BridgeEventsRepository(),
    child: MaterialApp(
      theme: buildTheme(
        preset: 'system',
        brightness: Brightness.dark,
        fontName: 'Onest',
        dynamicScheme: null,
      ),
      home: child,
    ),
  );
}

/// Pushes [screen] from a home button so back-pop can be observed.
/// Screens resolve their controllers through [AppScope].
Widget _pushed(Widget screen, AppState state) {
  return _wrap(
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => screen),
          ),
          child: const Text('open'),
        ),
      ),
    ),
    state,
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await initTestBackend();
  });

  testWidgets('capture save disabled when empty, enabled with text', (
    tester,
  ) async {
    final state = AppState(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      _wrap(CaptureScreen(state: state, onSaved: () {}), state),
    );
    await tester.pumpAndSettle();
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save ->'),
    );
    expect(save.onPressed, isNull);
    await tester.enterText(find.byType(TextField).first, 'draft');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save ->'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('capture back with draft shows the discard dialog', (
    tester,
  ) async {
    final state = AppState(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      _pushed(CaptureScreen(state: state, onSaved: () {}), state),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'draft');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('note viewer back with edits asks save/discard/cancel', (
    tester,
  ) async {
    await tester.runAsync(
      () => saveNoteFile(
        rootDir: Backend.root,
        relPath: 'home/shopping.md',
        newBody: '# Shopping\n\n- [ ] Milk\n',
      ),
    );
    final state = AppState(await SharedPreferences.getInstance());
    const file = NoteFileDto(
      relPath: 'home/shopping.md',
      fileName: 'shopping.md',
      security: SecurityLevel.open,
      about: '',
      headers: [],
    );
    await tester.pumpWidget(_pushed(const NoteViewerScreen(file: file), state));
    // Widget-triggered bridge loads need real async (FakeAsync swallows
    // native completions, so pumpAndSettle can never settle while loading).
    await tester.tap(find.text('open'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    expect(find.byTooltip('Edit'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '# Shopping\n\n- [ ] Jam\n');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('note viewer dialog save persists and pops', (tester) async {
    await tester.runAsync(
      () => saveNoteFile(
        rootDir: Backend.root,
        relPath: 'home/groceries.md',
        newBody: '# Groceries\n\n- [ ] Milk\n',
      ),
    );
    final state = AppState(await SharedPreferences.getInstance());
    const file = NoteFileDto(
      relPath: 'home/groceries.md',
      fileName: 'groceries.md',
      security: SecurityLevel.open,
      about: '',
      headers: [],
    );
    await tester.pumpWidget(_pushed(const NoteViewerScreen(file: file), state));
    await tester.tap(find.text('open'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '# Shopping\n\n- [ ] Jam\n');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    final content = await tester.runAsync(
      () => readNoteFile(rootDir: Backend.root, relPath: 'home/groceries.md'),
    );
    expect(content?.text, contains('Jam'));
  });
}
