import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/events_repository.dart';
import '../../data/models.dart';
import '../../data/settings_store.dart';
import '../../domain/dates.dart';
import '../../domain/events_view.dart';

/// Events tab state: shown month, selected day, agenda, and event writes.
/// Reloads whenever the storage [revision] moves. No `BuildContext`:
/// failures come back as messages for the widgets to show.
class EventsController extends ChangeNotifier {
  EventsController(
    this._repo,
    this._settings,
    this._revision, {
    required Future<void> Function(EventDto saved) afterSave,
    required Future<void> Function() refresh,
    DateTime Function()? clock,
  }) : _afterSave = afterSave,
       _refresh = refresh,
       _clock = clock ?? DateTime.now {
    final today = dayOf(_clock());
    month = DateTime(today.year, today.month);
    selected = today;
    _revision.addListener(_onRevision);
  }

  final EventsRepository _repo;
  final SettingsStore _settings;
  final Listenable _revision;
  final Future<void> Function(EventDto saved) _afterSave;
  final Future<void> Function() _refresh;
  final DateTime Function() _clock;
  bool _disposed = false;

  /// Returned by writes when sync changed the event; the view is reloaded.
  static const changedMessage = 'Changed on another device, reloaded';

  late DateTime month;
  late DateTime selected;
  List<CalendarCellDto> cells = const [];
  List<EventDto> dayEvents = const [];
  List<EventDto> agenda = const [];
  bool loading = true;
  String? error;

  /// Bumps on every storage change; pages that cache reads key on it.
  int generation = 0;

  DateTime get today => dayOf(_clock());
  EventsView get view => _settings.eventsView;

  Future<void> setView(EventsView v) async {
    await _settings.setEventsView(v);
    await load();
  }

  /// Load what the current view shows: month grid + selected day, or agenda.
  Future<void> load() async {
    loading = true;
    error = null;
    _notify();
    try {
      if (view == EventsView.month) {
        final (grid, day) = await (
          _repo.month(month, showWeekly: _settings.showWeekly),
          _repo.day(selected),
        ).wait;
        cells = grid;
        dayEvents = day;
      } else {
        agenda = await _repo.range(today, addDays(today, agendaDays - 1));
      }
    } on ParallelWaitError<
      (List<CalendarCellDto>?, List<EventDto>?),
      (AsyncError?, AsyncError?)
    > catch (e) {
      error = '${(e.errors.$1 ?? e.errors.$2)?.error}';
    } on AppFailure catch (e) {
      error = e.message;
    }
    loading = false;
    _notify();
  }

  void pageMonth(int delta) {
    month = shiftMonth(month, delta);
    unawaited(load());
  }

  void select(DateTime day) {
    selected = dayOf(day);
    if (day.month != month.month || day.year != month.year) {
      month = DateTime(day.year, day.month);
    }
    unawaited(load());
  }

  /// Weekly events of [day]; cached by the repository until a change.
  Future<List<EventDto>> weekly(Weekday day) => _repo.weekly(day);

  /// Pull external (sync) changes; the revision bump reloads the view.
  Future<void> refresh() async {
    try {
      await _refresh();
    } on AppFailure catch (e) {
      error = e.message;
      _notify();
    }
  }

  /// Create ([original] null) or replace an event. Null on success,
  /// else a message to show.
  Future<String?> save({EventDto? original, required EventDto updated}) =>
      _write(() async {
        if (original == null) {
          await _repo.add(updated);
        } else {
          await _repo.update(original, updated);
        }
        unawaited(_alarm(updated));
      });

  Future<String?> delete(EventDto original) =>
      _write(() => _repo.delete(original));

  Future<String?> _write(Future<void> Function() call) async {
    try {
      await call();
      return null;
    } on AppFailure catch (e) {
      if (e.kind != ErrorKind.changed) return e.message;
      await refresh();
      return changedMessage;
    }
  }

  Future<void> _alarm(EventDto saved) async {
    try {
      await _afterSave(saved);
    } on Exception catch (e) {
      // The event is saved; a missing alarm app must not look like a failure.
      debugPrint('auto alarm skipped: $e');
    }
  }

  void _onRevision() {
    generation++;
    unawaited(load());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision.removeListener(_onRevision);
    super.dispose();
  }
}
