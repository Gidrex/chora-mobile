import 'package:chora_mobile/domain/markdown_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const text =
      '# T\r\n- [ ] a\r\n  * [x] b\r\n```\r\n- [ ] code\r\n```\r\n+ [X] c\nplain\n- [?] no';

  test('tasks match the backend rules', () {
    final rows = noteBlocks(text).whereType<TaskRow>().toList();
    expect(rows.map((r) => r.line), [1, 2, 6]);
    expect(rows.map((r) => r.checked), [false, true, true]);
    expect(rows.map((r) => r.label), ['a', 'b', 'c']);
    expect(rows[1].indent, 2);
  });

  test('flip keeps line endings and skips fences', () {
    expect(flipTask(text, 1), text.replaceFirst('- [ ] a', '- [x] a'));
    expect(flipTask(text, 2), text.replaceFirst('* [x] b', '* [ ] b'));
    expect(flipTask(text, 6), text.replaceFirst('+ [X] c', '+ [ ] c'));
    expect(flipTask(text, 4), isNull, reason: 'inside fence');
    expect(flipTask(text, 3), isNull, reason: 'fence line');
    expect(flipTask(text, 7), isNull, reason: 'plain');
    expect(flipTask(text, 8), isNull, reason: 'bad mark');
    expect(flipTask(text, 99), isNull);
  });

  test('markdown around tasks is kept in chunks', () {
    final blocks = noteBlocks('# Title\n\n- [ ] x\n\nafter');
    expect(blocks.first, isA<MarkdownChunk>());
    expect((blocks.first as MarkdownChunk).text, '# Title\n');
    expect(blocks.last, isA<MarkdownChunk>());
  });
}
