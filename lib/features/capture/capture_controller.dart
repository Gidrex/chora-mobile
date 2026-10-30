import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../data/capture_repository.dart';
import '../../data/models.dart';
import '../../data/notes_repository.dart';
import '../../platform/notifications.dart';

/// Capture draft + submission. Owns the draft (plain values; the widget
/// owns `TextEditingController`s and mirrors text into [setTitle]/[setBody]),
/// project list, autocomplete data and the save flow. Reminder side effects
/// live here, not in the widget.
class CaptureController extends ChangeNotifier {
  CaptureController(this._repo, this._state) {
    _repo.revision.addListener(_onRevision);
  }

  final CaptureRepository _repo;
  final AppState _state;
  bool _disposed = false;

  List<ProjectDto> _projects = const [];
  bool loading = true;
  String? error;
  bool saving = false;

  String title = '';
  String body = '';
  String? targetNote;
  String? targetHeader;
  bool delegate = false;
  bool asEvent = false;
  DateTime eventDate = DateTime.now();
  TimeOfDay eventTime = TimeOfDay.now();
  String duration = '45m';
  String durationManual = '45m';
  Priority priority = Priority.medium;

  /// One-shot user message (`Saved → path`, error text).
  String? notice;
  void consumeNotice() {
    notice = null;
  }

  AppState get state => _state;

  /// Visible files minus projects hidden in Notes settings.
  List<NoteFileDto> get visibleFiles {
    final hidden = _state.hiddenProjects.toSet();
    return [
      for (final p in _projects)
        if (!hidden.contains(p.dir)) ...p.files,
    ];
  }

  bool get dirty =>
      title.isNotEmpty ||
      body.isNotEmpty ||
      targetNote != null ||
      delegate ||
      asEvent;

  bool get canSave => title.trim().isNotEmpty || body.trim().isNotEmpty;

  bool locked(NoteFileDto f) =>
      _state.needsGate(f.security.name) &&
      _state.fileUnlocked[f.relPath] != true;

  /// Header completions for the picked target, or empty when locked.
  List<String> headersFor(String token) {
    final file = visibleFiles.cast<NoteFileDto?>().firstWhere(
      (f) => f?.relPath == targetNote,
      orElse: () => null,
    );
    if (file == null || locked(file)) return const [];
    final q = (token.startsWith('#') ? token.substring(1) : token)
        .toLowerCase();
    return file.headers.where((h) => h.toLowerCase().contains(q)).toList();
  }

  /// Files matching a raw `@...` token (with optional `#header` suffix).
  /// `hit` is the matching header when the token joins one, else empty.
  List<({NoteFileDto file, String hit})> fileSuggestions(String token) {
    var query = token.startsWith('@') ? token.substring(1) : token;
    var headerQuery = '';
    final hash = query.indexOf('#');
    if (hash >= 0) {
      headerQuery = query.substring(hash + 1).toLowerCase();
      query = query.substring(0, hash);
    }
    final q = query.toLowerCase();
    final joinable = hash >= 0 && headerQuery.isNotEmpty;
    return [
      for (final f in visibleFiles.where(
        (f) => f.relPath.toLowerCase().contains(q),
      ))
        (
          file: f,
          hit: joinable
              ? f.headers.firstWhere(
                  (h) => h.toLowerCase().contains(headerQuery),
                  orElse: () => '',
                )
              : '',
        ),
    ];
  }

  void setTitle(String v) {
    if (title == v) return;
    title = v;
    _notify();
  }

  void setBody(String v) {
    if (body == v) return;
    body = v;
    _notify();
  }

  void pickFile(NoteFileDto file) {
    targetNote = file.relPath;
    targetHeader = null;
    _notify();
  }

  void pickHeader(String header) {
    targetHeader = header;
    _notify();
  }

  void clearTarget() {
    targetNote = null;
    targetHeader = null;
    _notify();
  }

  void setDelegate(bool v) {
    delegate = v;
    _notify();
  }

  void setAsEvent(bool v) {
    asEvent = v;
    _notify();
  }

  void setEventDate(DateTime d) {
    eventDate = d;
    _notify();
  }

  void stepEventTime(bool forward) {
    eventTime = _snapTime(eventTime, forward);
    _notify();
  }

  void setDuration(String v) {
    duration = v;
    durationManual = v;
    _notify();
  }

  void setDurationManual(String v) {
    durationManual = v;
    _notify();
  }

  void setPriority(Priority p) {
    priority = p;
    _notify();
  }

  void clearDraft() {
    title = '';
    body = '';
    targetNote = null;
    targetHeader = null;
    delegate = false;
    asEvent = false;
    duration = '45m';
    durationManual = '45m';
    _notify();
  }

  Future<void> reload() async {
    loading = true;
    error = null;
    _notify();
    try {
      _projects = await _repo.projects();
    } on NotesFailure catch (e) {
      error = e.message;
    }
    loading = false;
    _notify();
  }

  /// Submit the draft; returns the target path or null on error/empty.
  Future<String?> save() async {
    if (saving || !canSave) return null;
    saving = true;
    _notify();
    try {
      final durationValue = durationManual.trim().isEmpty
          ? duration
          : durationManual.trim();
      final path = await _repo.submit(
        title: title,
        body: body,
        targetNotePath: targetNote,
        targetHeader: targetHeader,
        delegateToAgent: delegate,
        createAsEvent: asEvent,
        eventDateIso: asEvent ? _isoOf(eventDate) : null,
        eventTimeHhmm: asEvent ? _hmOf(eventTime) : null,
        eventDuration: asEvent ? durationValue : null,
        priority: priority,
      );
      if (asEvent) {
        await Reminders.rescheduleUpcoming(
          enabled: _state.notifEnabled,
          minutesBefore: _state.notifMinutes,
        );
        await Reminders.maybeAutoAlarm(
          enabled: _state.autoAlarm,
          mode: _state.alarmMode,
          beforeMin: _state.alarmBeforeMin,
          event: EventDto(
            index: BigInt.zero,
            title: title,
            dateIso: _isoOf(eventDate),
            timeHhmm: _hmOf(eventTime),
            durationStr: durationValue,
            context: body,
            isRepeatable: false,
          ),
        );
      }
      clearDraft();
      notice = 'Saved → $path';
      _notify();
      return path;
    } on NotesFailure catch (e) {
      notice = e.message;
      _notify();
      return null;
    } finally {
      saving = false;
      _notify();
    }
  }

  /// Display strings for the event pickers (kept here so screens stay
  /// free of date formatting and bridge imports).
  String get eventDateLabel => _isoOf(eventDate);
  String get timeLabel => _hmOf(eventTime);

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

  static String _isoOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _hmOf(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Snap a time to the next (or previous) 15-minute mark.
TimeOfDay _snapTime(TimeOfDay t, bool forward) {
  var mins = t.hour * 60 + t.minute;
  mins = forward ? (mins ~/ 15 + 1) * 15 : ((mins - 1) ~/ 15) * 15;
  mins = mins % (24 * 60);
  return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
}
