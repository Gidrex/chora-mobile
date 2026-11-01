import 'package:chora_mobile/domain/dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iso round trip and DST-safe day math', () {
    expect(isoOf(DateTime(2026, 3, 9)), '2026-03-09');
    expect(dateOf('2026-03-09'), DateTime(2026, 3, 9));
    expect(addDays(DateTime(2026, 3, 28, 23), 2), DateTime(2026, 3, 30));
    expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027));
  });

  test('quarter snapping wraps midnight', () {
    expect(snapQuarter(9 * 60 + 7, forward: true), 9 * 60 + 15);
    expect(snapQuarter(9 * 60 + 15, forward: true), 9 * 60 + 30);
    expect(snapQuarter(9 * 60 + 15, forward: false), 9 * 60);
    expect(snapQuarter(9 * 60 + 7, forward: false), 9 * 60);
    expect(snapQuarter(23 * 60 + 50, forward: true), 0);
    expect(snapQuarter(0, forward: false), 23 * 60 + 45);
  });

  test('durations format and parse', () {
    expect(formatDuration(45 * 60), '45 min');
    expect(formatDuration(3600), '1 h');
    expect(formatDuration(5400), '1 h 30 min');
    expect(formatDuration(10), '10 s');
    expect(parseDuration('45'), 2700);
    expect(parseDuration('45m'), 2700);
    expect(parseDuration('1h 30m'), 5400);
    expect(parseDuration('1:30'), 5400);
    expect(parseDuration('2 hours'), 7200);
    expect(parseDuration('0'), isNull);
    expect(parseDuration('1:75'), isNull);
    expect(parseDuration('soon'), isNull);
    expect(parseDuration(''), isNull);
  });

  test('hhmm pads', () {
    expect(hhmm(9 * 60 + 5), '09:05');
  });
}
