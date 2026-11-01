import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/domain/reminders.dart';
import 'package:chora_mobile/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';

EventDto ev(
  String title,
  String date,
  int start, {
  EventSource source = EventSource.day,
  String context = '',
}) => EventDto(
  title: title,
  dateIso: date,
  startMin: start,
  durationSecs: 1800,
  context: context,
  source: source,
  index: 0,
);

void main() {
  final now = DateTime(2026, 11, 2, 10);

  test('plans only future reminders, weekly included', () {
    final plan = planReminders(
      [
        ev('Past', '2026-11-02', 9 * 60),
        ev('Soon', '2026-11-02', 10 * 60 + 10),
        ev('Gym', '2026-11-03', 19 * 60, source: EventSource.weekly),
      ],
      now: now,
      minutesBefore: 15,
    );
    expect(plan.map((r) => r.title), ['Gym']);
    expect(plan.single.at, DateTime(2026, 11, 3, 18, 45));
    final atStart = planReminders(
      [ev('Soon', '2026-11-02', 10 * 60 + 10)],
      now: now,
      minutesBefore: 0,
    );
    expect(atStart.single.body, 'Starting now · 10:10');
  });

  test('auto alarm: first of day, tag, weekly never', () {
    final a = ev('A', '2026-11-03', 8 * 60);
    final b = ev('B', '2026-11-03', 9 * 60, context: '#alarm');
    expect(
      autoAlarmAt(
        a,
        [a, b],
        mode: AlarmMode.first,
        minutesBefore: 30,
        now: now,
      ),
      DateTime(2026, 11, 3, 7, 30),
    );
    expect(
      autoAlarmAt(
        b,
        [a, b],
        mode: AlarmMode.first,
        minutesBefore: 30,
        now: now,
      ),
      isNull,
    );
    expect(
      autoAlarmAt(b, [a, b], mode: AlarmMode.tag, minutesBefore: 0, now: now),
      DateTime(2026, 11, 3, 9),
    );
    final weekly = ev('W', '2026-11-03', 6 * 60, source: EventSource.weekly);
    expect(
      autoAlarmAt(
        weekly,
        [weekly],
        mode: AlarmMode.first,
        minutesBefore: 0,
        now: now,
      ),
      isNull,
    );
  });

  test('gate thresholds', () {
    expect(needsGate(SecurityLevel.critical, SecurityThreshold.none), isFalse);
    expect(needsGate(SecurityLevel.open, SecurityThreshold.open), isTrue);
    expect(
      needsGate(SecurityLevel.open, SecurityThreshold.restricted),
      isFalse,
    );
    expect(
      needsGate(SecurityLevel.restricted, SecurityThreshold.restricted),
      isTrue,
    );
    expect(
      needsGate(SecurityLevel.restricted, SecurityThreshold.critical),
      isFalse,
    );
    expect(
      needsGate(SecurityLevel.critical, SecurityThreshold.critical),
      isTrue,
    );
  });
}
