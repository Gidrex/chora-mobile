import 'package:chora_mobile/domain/capture_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('continuedMarker keeps checklist going after Enter', () {
    expect(continuedMarker('- [ ] milk'), '- [ ] ');
    expect(continuedMarker('  - [x] done'), '  - [ ] ');
    expect(continuedMarker('plain text'), isNull);
    expect(continuedMarker('- [ ]'), isNull);
  });

  test('activeToken finds @ and # tokens before the cursor', () {
    expect(activeToken('buy @vault/sec', 14, hashEnabled: false), '@vault/sec');
    expect(activeToken('pick #head', 10, hashEnabled: true), '#head');
    // '#' completes headers only after a file was picked.
    expect(activeToken('pick #head', 10, hashEnabled: false), isNull);
    expect(activeToken('no token here', 8, hashEnabled: true), isNull);
    // A '#' later in the token wins (matches the screen's regex).
    expect(activeToken('@a#Head', 7, hashEnabled: true), '#Head');
    expect(activeToken('', 0, hashEnabled: true), isNull);
    expect(activeToken('abc', 99, hashEnabled: true), isNull);
  });

  test('continueChecklist extends a checklist line after Enter', () {
    expect(
      continueChecklist('- [ ] milk\n', '- [ ] milk'),
      '- [ ] milk\n- [ ] ',
    );
    expect(continueChecklist('plain\n', 'plain'), isNull);
    expect(continueChecklist('- [ ] milk\nX', '- [ ] milk\n'), isNull);
  });

  test('insertSnippet replaces the range and moves the cursor', () {
    final r = insertSnippet('buy  and', 4, 4, '@sec');
    expect(r.text, 'buy @sec and');
    expect(r.offset, 8);
  });

  test('insertCheckboxLine starts the current line with a checkbox', () {
    final r = insertCheckboxLine('a\nb', 3);
    expect(r.text, 'a\n- [ ] b');
    expect(r.offset, 9);
  });

  test('replaceToken swaps the token and moves the cursor', () {
    final r = replaceToken('buy @sec and', 8, '');
    expect(r.text, 'buy  and');
    expect(r.offset, 4);
    final same = replaceToken('plain', 5, 'x');
    expect(same.text, 'plain');
    expect(same.offset, 5);
  });
}
