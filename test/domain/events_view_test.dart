import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/domain/events_view.dart';
import 'package:flutter_test/flutter_test.dart';

EventDto ev(String title, String date) => EventDto(
  title: title,
  dateIso: date,
  startMin: 600,
  durationSecs: 1800,
  context: '',
  source: EventSource.day,
  index: 0,
);

void main() {
  test('weekday mapping and next occurrence', () {
    final sunday = DateTime(2026, 11, 1);
    expect(weekdayOf(sunday), Weekday.sunday);
    expect(weekdayOf(DateTime(2026, 11, 2)), Weekday.monday);
    expect(nextWeekday(Weekday.sunday, sunday), DateTime(2026, 11, 1));
    expect(nextWeekday(Weekday.monday, sunday), DateTime(2026, 11, 2));
    expect(nextWeekday(Weekday.saturday, sunday), DateTime(2026, 11, 7));
  });

  test('month paging crosses years', () {
    expect(shiftMonth(DateTime(2026, 12), 1), DateTime(2027));
    expect(shiftMonth(DateTime(2026), -1), DateTime(2025, 12));
  });

  test('groups consecutive events by day', () {
    final groups = groupByDay([
      ev('a', '2026-11-01'),
      ev('b', '2026-11-01'),
      ev('c', '2026-11-03'),
    ]);
    expect(groups.map((g) => g.day), [
      DateTime(2026, 11, 1),
      DateTime(2026, 11, 3),
    ]);
    expect(groups.first.events.map((e) => e.title), ['a', 'b']);
    expect(groupByDay(const []), isEmpty);
  });
}
