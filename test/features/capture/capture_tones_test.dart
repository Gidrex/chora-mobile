import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/features/capture/widgets/priority_selector.dart';
import 'package:chora_mobile/features/capture/widgets/target_chip.dart';
import 'package:chora_mobile/ui/theme.dart';
import 'package:chora_mobile/ui/tones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _todo = NoteFileDto(
  relPath: 'work/todo.md',
  name: 'todo.md',
  title: 'Todo',
  security: SecurityLevel.open,
  about: '',
  headers: ['Tasks'],
);

void main() {
  testWidgets('target chips and priorities use their tones', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          preset: 'ambient',
          brightness: Brightness.dark,
          fontName: 'Onest',
        ),
        home: Scaffold(
          body: Column(
            children: [
              TargetRow(
                target: _todo,
                header: 'Tasks',
                emptyLabel: 'Inbox',
                showSection: true,
                onPickNote: () {},
                onPickSection: () {},
                onClear: () {},
              ),
              PrioritySelector(priority: Priority.high, onChanged: (_) {}),
            ],
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(TargetRow));
    final tones = Tones.of(context);
    final chips = tester.widgetList<InputChip>(find.byType(InputChip)).toList();
    expect(chips[0].labelStyle?.color, tones.file);
    expect(chips[1].labelStyle?.color, tones.section);
    final urgent = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Urgent'),
    );
    expect(urgent.labelStyle?.color, Theme.of(context).colorScheme.error);
  });
}
