import 'package:chora_mobile/app/services.dart';
import 'package:chora_mobile/features/capture/capture_controller.dart';
import 'package:chora_mobile/features/capture/capture_screen.dart';
import 'package:chora_mobile/ui/cloud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_backend.dart';

/// Let bridge futures complete (FakeAsync never runs native completions).
Future<void> settleBridge(WidgetTester tester) async {
  // Each bridge hop needs a real event loop turn; writes take several.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AppServices services;

  testWidgets('typing a title and saving appends to the inbox', (tester) async {
    services = (await tester.runAsync(testServices))!;
    await tester.pumpWidget(harness(services, const CaptureScreen()));
    await settleBridge(tester);

    Finder save() => find.widgetWithText(FilledButton, 'Save');
    expect(tester.widget<FilledButton>(save()).onPressed, isNull);
    expect(find.byType(CloudArt), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Buy milk');
    await tester.pump();
    expect(tester.widget<FilledButton>(save()).onPressed, isNotNull);

    await tester.tap(save());
    await settleBridge(tester);
    expect(find.text('Saved to inbox.md'), findsOneWidget);
    final note = await tester.runAsync(() => services.notes.note('inbox.md'));
    expect(note!.text, contains('## Buy milk'));
    expect(tester.widget<FilledButton>(save()).onPressed, isNull);
  });

  testWidgets('capture lands under the picked section on disk', (tester) async {
    services = (await tester.runAsync(testServices))!;
    final c = await tester.runAsync(() async {
      await services.notes.save(
        'work/todo.md',
        '# Todo\n\n## Tasks\n\n- [ ] a\n\n## Bugs\n\n- [ ] b\n',
        base: '',
      );
      final c = CaptureController(
        notes: services.notes,
        events: services.events,
        settings: services.settings,
        locked: services.lock.locked,
        revision: services.session.revision,
      );
      await c.reload();
      c
        ..pickFile(c.files.firstWhere((f) => f.relPath == 'work/todo.md'))
        ..pickHeader('Tasks')
        ..setBody('- [ ] new');
      await c.save();
      return c;
    });
    expect(c!.notice, 'Saved to work/todo.md');
    final text = (await tester.runAsync(
      () => services.notes.note('work/todo.md'),
    ))!.text;
    expect(text.indexOf('- [ ] new'), lessThan(text.indexOf('## Bugs')));
    c.dispose();
  });

  for (final mode in CaptureMode.values) {
    testWidgets('no overflow at 320 dp and text scale 2 ($mode)', (
      tester,
    ) async {
      services = (await tester.runAsync(testServices))!;
      tester.view
        ..physicalSize = const Size(320, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(2),
          ),
          child: harness(services, const CaptureScreen()),
        ),
      );
      await settleBridge(tester);
      await tester.tap(
        find.text(switch (mode) {
          CaptureMode.note => 'Note',
          CaptureMode.event => 'Event',
          CaptureMode.agent => 'Agent',
        }),
      );
      await tester.pump();
      if (mode == CaptureMode.event) {
        await tester.ensureVisible(find.text('Custom'));
        await tester.pump();
        await tester.tap(find.text('Custom'));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
