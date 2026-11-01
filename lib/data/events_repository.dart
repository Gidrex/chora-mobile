import '../domain/dates.dart';
import 'models.dart';
import 'vault_session.dart';

/// Calendar months, days and weekly events. Reads are cached until the
/// session revision moves; writes go through [VaultSession.write].
class EventsRepository {
  EventsRepository(this._session) {
    _session.revision.addListener(_cache.clear);
  }

  final VaultSession _session;
  final _cache = <String, Future<Object>>{};

  Future<T> _cached<T extends Object>(
    String key,
    Future<T> Function() load,
  ) async {
    final hit = _cache[key];
    if (hit != null) return await hit as T;
    final future = load();
    _cache[key] = future;
    try {
      return await future;
    } on Object {
      _cache.remove(key)?.ignore(); // let the next call retry
      rethrow;
    }
  }

  Future<List<CalendarCellDto>> month(
    DateTime month, {
    required bool showWeekly,
  }) => _cached(
    'm:${month.year}-${month.month}-$showWeekly',
    () => _session.read(
      (v) =>
          v.month(year: month.year, month: month.month, showWeekly: showWeekly),
    ),
  );

  Future<List<EventDto>> day(DateTime date) => _cached(
    'd:${isoOf(date)}',
    () => _session.read((v) => v.day(dateIso: isoOf(date))),
  );

  /// Every event in `from..=to` (at most 92 days), by date then time.
  Future<List<EventDto>> range(DateTime from, DateTime to) => _cached(
    'r:${isoOf(from)}:${isoOf(to)}',
    () => _session.read((v) => v.range(fromIso: isoOf(from), toIso: isoOf(to))),
  );

  Future<List<EventDto>> weekly(Weekday day) => _cached(
    'w:${day.name}',
    () => _session.read((v) => v.weekly(weekday: day)),
  );

  Future<void> add(EventDto event) =>
      _session.write((v) => v.addEvent(event: event));

  /// Replace [original] exactly as it was read; fails with
  /// [ErrorKind.changed] when sync changed it meanwhile.
  Future<void> update(EventDto original, EventDto updated) => _session.write(
    (v) => v.updateEvent(original: original, updated: updated),
  );

  Future<void> delete(EventDto original) =>
      _session.write((v) => v.deleteEvent(original: original));

  void dispose() => _session.revision.removeListener(_cache.clear);
}
