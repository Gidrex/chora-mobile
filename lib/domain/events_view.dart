import '../data/models.dart';
import 'dates.dart';

/// Duration presets offered by the event form, in seconds.
const durationPresets = [15 * 60, 30 * 60, 45 * 60, 60 * 60, 2 * 60 * 60];

/// Days the agenda shows, starting today.
const agendaDays = 14;

/// The bridge [Weekday] of a date.
Weekday weekdayOf(DateTime d) => Weekday.values[d.weekday - 1];

/// Next date (today included) that falls on [day].
DateTime nextWeekday(Weekday day, DateTime from) =>
    addDays(dayOf(from), (day.index - (from.weekday - 1)) % 7);

/// First day of the month [delta] months after [month].
DateTime shiftMonth(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

/// [events] (sorted by date, then time) grouped per day, in order.
List<({DateTime day, List<EventDto> events})> groupByDay(
  List<EventDto> events,
) {
  final out = <({DateTime day, List<EventDto> events})>[];
  for (final e in events) {
    final day = dateOf(e.dateIso);
    if (out.isEmpty || !sameDay(out.last.day, day)) {
      out.add((day: day, events: [e]));
    } else {
      out.last.events.add(e);
    }
  }
  return out;
}
