import 'package:flutter/foundation.dart';

import '../backend.dart' as backend;
import 'models.dart';
import 'notes_repository.dart';

/// Month grid (cached per month), day events and repeatables over the
/// bridge. Writes bump [revision]; widgets refresh through a controller.
abstract class EventsRepository {
  ValueListenable<int> get revision;

  /// Drop all caches and bump [revision] (Syncthing may have changed files).
  Future<void> invalidate();

  Future<List<CalendarCellDto>> monthGrid(
    int year,
    int month, {
    required bool showRepeat,
  });

  Future<DayEventsDto> dayEvents(String dateIso);
  Future<void> createEvent(EventDto event);
  Future<void> updateEvent(
    String originalDateIso,
    BigInt sectionIndex,
    EventDto updated,
  );
  Future<void> deleteEvent(String dateIso, BigInt sectionIndex);

  Future<List<EventDto>> repeatables(String weekday);
  Future<void> saveRepeatables(String weekday, List<EventDto> events);
}

class BridgeEventsRepository implements EventsRepository {
  final _revision = ValueNotifier<int>(0);
  final _monthCache = <String, List<CalendarCellDto>>{};
  final _dayCache = <String, DayEventsDto>{};
  final _repeatCache = <String, List<EventDto>>{};

  @override
  ValueListenable<int> get revision => _revision;

  void _bump() {
    _monthCache.clear();
    _dayCache.clear();
    _repeatCache.clear();
    _revision.value++;
  }

  @override
  Future<void> invalidate() async {
    _monthCache.clear();
    _dayCache.clear();
    _repeatCache.clear();
    _revision.value++;
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw NotesFailure(backend.Backend.errMsg(e));
    }
  }

  @override
  Future<List<CalendarCellDto>> monthGrid(
    int year,
    int month, {
    required bool showRepeat,
  }) async {
    final key = '$year-$month-$showRepeat';
    final cached = _monthCache[key];
    if (cached != null) return cached;
    final cells = await _guard(
      () => backend.getCalendarMonth(
        rootDir: backend.Backend.root,
        year: year,
        month: month,
        showRepeat: showRepeat,
      ),
    );
    _monthCache[key] = cells;
    return cells;
  }

  @override
  Future<DayEventsDto> dayEvents(String dateIso) async {
    final cached = _dayCache[dateIso];
    if (cached != null) return cached;
    final day = await _guard(
      () =>
          backend.getDayEvents(rootDir: backend.Backend.root, dateIso: dateIso),
    );
    _dayCache[dateIso] = day;
    return day;
  }

  @override
  Future<void> createEvent(EventDto event) async {
    await _guard(
      () => backend.createEvent(rootDir: backend.Backend.root, event: event),
    );
    _bump();
  }

  @override
  Future<void> updateEvent(
    String originalDateIso,
    BigInt sectionIndex,
    EventDto updated,
  ) async {
    await _guard(
      () => backend.updateSingleEvent(
        rootDir: backend.Backend.root,
        originalDateIso: originalDateIso,
        sectionIndex: sectionIndex,
        updated: updated,
      ),
    );
    _bump();
  }

  @override
  Future<void> deleteEvent(String dateIso, BigInt sectionIndex) async {
    await _guard(
      () => backend.deleteSingleEvent(
        rootDir: backend.Backend.root,
        dateIso: dateIso,
        sectionIndex: sectionIndex,
      ),
    );
    _bump();
  }

  @override
  Future<List<EventDto>> repeatables(String weekday) async {
    final cached = _repeatCache[weekday];
    if (cached != null) return cached;
    final events = await _guard(
      () => backend.getRepeatableWeekday(
        rootDir: backend.Backend.root,
        weekday: weekday,
      ),
    );
    _repeatCache[weekday] = events;
    return events;
  }

  @override
  Future<void> saveRepeatables(String weekday, List<EventDto> events) async {
    await _guard(
      () => backend.saveRepeatableWeekday(
        rootDir: backend.Backend.root,
        weekday: weekday,
        events: events,
      ),
    );
    _bump();
  }
}
