import '../data/models.dart';
import 'dates.dart';

/// Which saved event gets an automatic system alarm.
enum AlarmMode {
  first('First event of the day'),
  tag('Events tagged #alarm');

  const AlarmMode(this.label);

  final String label;
}

/// One notification to schedule.
typedef PlannedReminder = ({int id, String title, String body, DateTime at});

/// Android keeps a few hundred alarms per app; stay far below.
const maxReminders = 64;

/// Reminders for [events] that fire after [now], [minutesBefore] each start.
List<PlannedReminder> planReminders(
  List<EventDto> events, {
  required DateTime now,
  required int minutesBefore,
}) {
  final out = <PlannedReminder>[];
  for (final e in events) {
    final start = atMinute(dateOf(e.dateIso), e.startMin);
    final at = start.subtract(Duration(minutes: minutesBefore));
    if (!at.isAfter(now)) continue;
    final when = minutesBefore == 0 ? 'Starting now' : 'In $minutesBefore min';
    out.add((
      id: out.length,
      title: e.title,
      body: '$when · ${hhmm(e.startMin)}',
      at: at,
    ));
    if (out.length == maxReminders) break;
  }
  return out;
}

/// When to ring a system alarm for a just-saved [saved] event, or null.
/// [sameDay] are all events of its day after the save.
DateTime? autoAlarmAt(
  EventDto saved,
  List<EventDto> sameDay, {
  required AlarmMode mode,
  required int minutesBefore,
  required DateTime now,
}) {
  if (saved.source == EventSource.weekly) return null;
  final ok = switch (mode) {
    AlarmMode.tag => '${saved.title} ${saved.context}'.contains('#alarm'),
    AlarmMode.first =>
      sameDay
          .where((e) => e.source == EventSource.day)
          .every((e) => e.startMin >= saved.startMin),
  };
  if (!ok) return null;
  final at = atMinute(
    dateOf(saved.dateIso),
    saved.startMin,
  ).subtract(Duration(minutes: minutesBefore));
  return at.isAfter(now) ? at : null;
}
