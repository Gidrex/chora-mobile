import 'package:chora_mobile/domain/event_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseHm reads HH:MM or returns null', () {
    expect(parseHm('09:30'), const TimeOfDay(hour: 9, minute: 30));
    expect(parseHm('9:5'), const TimeOfDay(hour: 9, minute: 5));
    expect(parseHm('nope'), isNull);
    expect(parseHm('10'), isNull);
  });

  test('parseMinutes reads 45m, 1h, 1h30m', () {
    expect(parseMinutes('45m'), 45);
    expect(parseMinutes('1h'), 60);
    expect(parseMinutes('1h30m'), 90);
    expect(parseMinutes(''), isNull);
    expect(parseMinutes('soon'), isNull);
  });

  test('humanDuration spells hours and minutes', () {
    expect(humanDuration('45m'), '45 minutes');
    expect(humanDuration('1h'), '1 hour');
    expect(humanDuration('1h30m'), '1 hour 30 minutes');
    expect(humanDuration('soon'), 'soon');
  });

  test('format12 renders 12-hour clock', () {
    expect(format12(const TimeOfDay(hour: 9, minute: 5)), '9:05 AM');
    expect(format12(const TimeOfDay(hour: 15, minute: 30)), '3:30 PM');
  });
}
