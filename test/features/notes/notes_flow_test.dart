import 'package:chora_mobile/app/services.dart';
import 'package:chora_mobile/domain/security.dart';
import 'package:chora_mobile/features/notes/notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_backend.dart';

/// Let bridge futures finish, then render.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('open a note, toggle a task, back from dirty edit asks', (
    tester,
  ) async {
    final services = (await tester.runAsync(() async {
      final s = await testServices();
      await s.notes.save('work/todo.md', '# Todo\n\n- [ ] Ship\n', base: '');
      await s.notes.save('work/guides/deploy.md', '# Deploy\n', base: '');
      return s;
    }))!;
    await tester.pumpWidget(harness(services, const NotesScreen()));
    await settle(tester);

    // Project open by default: file name, then its h1; folders closed.
    expect(find.text('work'), findsOneWidget);
    expect(find.text('todo.md'), findsOneWidget);
    expect(find.text('Todo'), findsOneWidget);
    expect(find.text('deploy.md'), findsNothing);
    await tester.tap(find.text('guides'));
    await settle(tester);
    expect(find.text('deploy.md'), findsOneWidget);
    expect(find.text('Deploy'), findsOneWidget);
    await tester.tap(find.text('guides'));
    await settle(tester);
    expect(find.text('deploy.md'), findsNothing);

    await tester.tap(find.text('todo.md'));
    await settle(tester);

    await tester.tap(find.text('Ship'));
    await settle(tester);
    final onDisk = await tester.runAsync(
      () => services.notes.note('work/todo.md'),
    );
    expect(onDisk!.text, contains('- [x] Ship'));

    await tester.tap(find.byTooltip('Edit'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'changed');
    await tester.pump();
    await tester.pageBack();
    await tester.pump();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('search shows only matching files', (tester) async {
    final AppServices services = (await tester.runAsync(() async {
      final s = await testServices();
      await s.notes.save('work/todo.md', '# Todo\n', base: '');
      await s.notes.save('work/guides/deploy.md', '# Deploy\n', base: '');
      return s;
    }))!;
    await tester.pumpWidget(harness(services, const NotesScreen()));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'deploy');
    await settle(tester);
    // The match sits in a closed folder: search opens its ancestors.
    expect(find.text('deploy.md'), findsOneWidget);
    expect(find.text('guides'), findsOneWidget);
    expect(find.text('todo.md'), findsNothing);
  });

  testWidgets('a locked note hides its h1', (tester) async {
    final AppServices services = (await tester.runAsync(() async {
      final s = await testServices();
      await s.notes.save('work/todo.md', '# Secret plan\n', base: '');
      return s;
    }))!;
    // "Everything" gates every note until an unlock this session.
    await services.settings.setSecurityThreshold(SecurityThreshold.open);
    await tester.pumpWidget(harness(services, const NotesScreen()));
    await settle(tester);
    expect(find.text('todo.md'), findsOneWidget);
    expect(find.text('Secret plan'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
  });
  testWidgets('list survives 320 dp and text scale 2.0', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final services = (await tester.runAsync(() async {
      final s = await testServices();
      await s.notes.save(
        'a-rather-long-project/deep/er/nested/notes-with-long-name.md',
        '# A long heading that must ellipsize\n',
        base: '',
      );
      return s;
    }))!;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: harness(services, const NotesScreen()),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('a-rather-long-project'));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
