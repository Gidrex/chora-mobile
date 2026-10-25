import 'package:chora_mobile/backend.dart';
import 'package:chora_mobile/screens/capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isoOf formats a date as YYYY-MM-DD', () {
    expect(Backend.isoOf(DateTime(2026, 3, 5)), '2026-03-05');
    expect(Backend.isoOf(DateTime(2026, 11, 20)), '2026-11-20');
  });

  test('dateOf parses ISO dates back', () {
    final date = Backend.dateOf('2026-11-20');
    expect((date.year, date.month, date.day), (2026, 11, 20));
  });

  test('continuedMarker keeps checklist going after Enter', () {
    expect(continuedMarker('- [ ] milk'), '- [ ] ');
    expect(continuedMarker('  - [x] done'), '  - [ ] ');
    expect(continuedMarker('plain text'), isNull);
    expect(continuedMarker('- [ ]'), isNull);
  });

  test('errMsg strips exception prefixes to one line', () {
    expect(Backend.errMsg(Exception('plain failure')), 'plain failure');
    expect(
      Backend.errMsg(
        'FrbAnyhowException: bad date `x`: expected more\nsecond line',
      ),
      'bad date `x`: expected more',
    );
  });
}
