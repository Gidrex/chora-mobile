import 'package:chora_mobile/data/events_repository.dart';
import 'package:chora_mobile/data/models.dart';

EventDto ev(String title, {int start = 600}) => EventDto(
  title: title,
  dateIso: '2026-11-02',
  startMin: start,
  durationSecs: 1800,
  context: '',
  source: EventSource.day,
  index: 0,
);

class FakeEventsRepository implements EventsRepository {
  final List<EventDto> stored = [];
  final calls = <String>[];
  AppFailure? failWrite;

  @override
  Future<List<CalendarCellDto>> month(
    DateTime m, {
    required bool showWeekly,
  }) async {
    calls.add('month ${m.month}');
    return const [];
  }

  @override
  Future<List<EventDto>> day(DateTime d) async {
    calls.add('day ${d.day}');
    return List.of(stored);
  }

  @override
  Future<List<EventDto>> range(DateTime from, DateTime to) async {
    calls.add('range ${from.day}-${to.day}');
    return List.of(stored);
  }

  @override
  Future<List<EventDto>> weekly(Weekday day) async => const [];

  Future<void> _write(void Function() change) async {
    final fail = failWrite;
    if (fail != null) throw fail;
    change();
  }

  @override
  Future<void> add(EventDto event) => _write(() => stored.add(event));

  @override
  Future<void> update(EventDto original, EventDto updated) => _write(() {
    stored[stored.indexOf(original)] = updated;
  });

  @override
  Future<void> delete(EventDto original) =>
      _write(() => stored.remove(original));

  @override
  void dispose() {}
}
