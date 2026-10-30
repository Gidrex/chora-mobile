import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/settings_store.dart';
import '../../data/events_repository.dart';
import '../../data/models.dart';
import '../../data/notes_repository.dart';
import '../../platform/notifications.dart';

/// Events screen state: month grid, repeatables, and one-shot day loads.
/// Day snapshots stay in the widgets (popover, list); CRUD and reminders
/// live here. No `BuildContext`; errors surface as values.
class EventsController extends ChangeNotifier {
  EventsController(this._repo, this._state) {
    _repo.revision.addListener(_onRevision);
  }

  final EventsRepository _repo;
  final SettingsStore _state;
  bool _disposed = false;

  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  List<CalendarCellDto> cells = const [];
  bool monthLoading = true;
  String? error;

  String repeatDay = weekdays[(DateTime.now().weekday - 1) % 7];
  List<EventDto> repeatEvents = const [];
  bool repeatLoading = true;

  /// One-shot user message (error text); widgets render and clear it.
  String? notice;
  void consumeNotice() {
    notice = null;
  }

  SettingsStore get state => _state;

  Future<void> reload() async {
    await Future.wait([loadMonth(), loadRepeatables()]);
  }

  Future<void> loadMonth() async {
    monthLoading = true;
    error = null;
    _notify();
    try {
      cells = await _repo.monthGrid(
        month.year,
        month.month,
        showRepeat: _state.showRepeat,
      );
    } on NotesFailure catch (e) {
      error = e.message;
    }
    monthLoading = false;
    _notify();
  }

  void setMonth(DateTime m) {
    month = DateTime(m.year, m.month);
    unawaited(loadMonth());
  }

  void pageMonth(int delta) {
    setMonth(DateTime(month.year, month.month + delta));
  }

  Future<void> loadRepeatables() async {
    repeatLoading = true;
    _notify();
    try {
      repeatEvents = await _repo.repeatables(repeatDay);
    } on NotesFailure catch (e) {
      notice = e.message;
    }
    repeatLoading = false;
    _notify();
  }

  void setRepeatDay(String day) {
    if (repeatDay == day) return;
    repeatDay = day;
    unawaited(loadRepeatables());
  }

  /// Day snapshot for popover/list views (repository-cached).
  Future<DayEventsDto> loadDay(String dateIso) => _repo.dayEvents(dateIso);

  /// Reminder side effects for a saved event (moved out of the widget).
  Future<void> _remind(EventDto dto) async {
    await Reminders.rescheduleUpcoming(
      enabled: _state.notifEnabled,
      minutesBefore: _state.notifMinutes,
    );
    await Reminders.maybeAutoAlarm(
      enabled: _state.autoAlarm,
      mode: _state.alarmMode.name,
      beforeMin: _state.alarmBeforeMin,
      event: dto,
    );
  }

  /// Form-owned flows: returns the error message, or null on success.
  /// The form shows it with its own context (visible above dialogs);
  /// screen-owned flows below use [notice] instead.
  Future<String?> createEvent(EventDto dto) async {
    try {
      await _repo.createEvent(dto);
      await _remind(dto);
      return null;
    } on NotesFailure catch (e) {
      return e.message;
    }
  }

  Future<String?> updateEvent(
    String originalDateIso,
    BigInt sectionIndex,
    EventDto dto,
  ) async {
    try {
      await _repo.updateEvent(originalDateIso, sectionIndex, dto);
      await _remind(dto);
      return null;
    } on NotesFailure catch (e) {
      return e.message;
    }
  }

  Future<String?> deleteEvent(String dateIso, BigInt sectionIndex) async {
    try {
      await _repo.deleteEvent(dateIso, sectionIndex);
      return null;
    } on NotesFailure catch (e) {
      return e.message;
    }
  }

  List<EventDto> _renumbered(List<EventDto> events) => [
    for (var i = 0; i < events.length; i++)
      EventDto(
        index: BigInt.from(i),
        title: events[i].title,
        dateIso: events[i].dateIso,
        timeHhmm: events[i].timeHhmm,
        durationStr: events[i].durationStr,
        context: events[i].context,
        isRepeatable: true,
      ),
  ];

  Future<void> saveRepeatables(List<EventDto> events) async {
    try {
      await _repo.saveRepeatables(repeatDay, _renumbered(events));
    } on NotesFailure catch (e) {
      notice = e.message;
      _notify();
    }
  }

  /// Insert or replace one repeatable, then persist the day.
  Future<void> upsertRepeatable({
    required EventDto? existing,
    required int? index,
    required EventDto dto,
  }) async {
    final next = [...repeatEvents];
    if (existing != null && index != null) {
      next[index] = dto;
    } else {
      next.add(dto);
    }
    await saveRepeatables(next);
  }

  Future<void> deleteRepeatable(int index) async {
    final next = [...repeatEvents]..removeAt(index);
    await saveRepeatables(next);
  }

  void _onRevision() {
    unawaited(reload());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _repo.revision.removeListener(_onRevision);
    super.dispose();
  }
}

/// Monday-first weekday keys for repeatables.
const weekdays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];
