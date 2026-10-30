import 'package:chora_mobile/backend.dart';
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
