import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/events_repository.dart';
import '../../data/models.dart';
import '../../data/notes_repository.dart';
import '../../data/settings_store.dart';
import '../../domain/dates.dart';

/// Where a capture goes.
enum CaptureMode { note, event, agent }

/// Duration presets offered as chips, in seconds.
const durationPresets = [15 * 60, 30 * 60, 45 * 60, 60 * 60, 120 * 60];

/// Capture draft and submission. Plain values only: the screen owns the
/// text controllers and mirrors their text into [setTitle]/[setBody].
class CaptureController extends ChangeNotifier {
  CaptureController({
    required NotesRepository notes,
    required EventsRepository events,
    required SettingsStore settings,
    required bool Function(SecurityLevel level) locked,
    required Listenable revision,
    Future<void> Function(EventDto saved)? onEventSaved,
    DateTime Function() clock = DateTime.now,
  }) : _notes = notes,
       _events = events,
       _settings = settings,
       _locked = locked,
       _revision = revision,
       _onEventSaved = onEventSaved,
       _clock = clock {
    _revision.addListener(_onRevision);
    resetEventTime();
  }

  final NotesRepository _notes;
  final EventsRepository _events;
  final SettingsStore _settings;
  final bool Function(SecurityLevel level) _locked;
  final Listenable _revision;
  final Future<void> Function(EventDto saved)? _onEventSaved;
  final DateTime Function() _clock;
  bool _disposed = false;

  List<ProjectDto> _projects = const [];
  bool saving = false;

  CaptureMode mode = CaptureMode.note;
  String title = '';
  String body = '';
  NoteFileDto? target;
  String? targetHeader;
  Priority priority = Priority.medium;
  late DateTime eventDate;
  late int startMin;
  bool weekly = false;

  /// Selected preset in seconds; null = custom text in [customDuration].
  int? presetDuration = 45 * 60;
  String customDuration = '';

  /// One-shot message for a snackbar; the screen reads and clears it.
  String? notice;

  /// Files of all projects the user did not hide in Notes.
  List<NoteFileDto> get files {
    final hidden = _settings.hiddenProjects.toSet();
    return [
      for (final p in _projects)
        if (!hidden.contains(p.name)) ...p.files,
    ];
  }

  bool locked(NoteFileDto file) => _locked(file.security);

  int? get durationSecs => presetDuration ?? parseDuration(customDuration);

  String? get durationError => presetDuration == null && durationSecs == null
      ? 'Like 45m, 1h30m or 1:30'
      : null;

  bool get dirty =>
      title.trim().isNotEmpty || body.trim().isNotEmpty || target != null;

  bool get canSave {
    if (saving) return false;
    return switch (mode) {
      CaptureMode.note => title.trim().isNotEmpty || body.trim().isNotEmpty,
      CaptureMode.agent => title.trim().isNotEmpty,
      CaptureMode.event => title.trim().isNotEmpty && durationSecs != null,
    };
  }

  /// Headers of the target matching [query], empty while it is locked.
  List<String> headersFor(String query) {
    final file = target;
    if (file == null || locked(file)) return const [];
    final q = query.toLowerCase();
    return file.headers.where((h) => h.toLowerCase().contains(q)).toList();
  }

  /// Files whose path contains [query].
  List<NoteFileDto> filesFor(String query) {
    final q = query.toLowerCase();
    return files.where((f) => f.relPath.toLowerCase().contains(q)).toList();
  }

  void setMode(CaptureMode v) => _set(() => mode = v);
  void setTitle(String v) => _set(() => title = v);
  void setBody(String v) => _set(() => body = v);
  void setPriority(Priority v) => _set(() => priority = v);
  void setWeekly(bool v) => _set(() => weekly = v);
  void setEventDate(DateTime d) => _set(() => eventDate = dayOf(d));
  void shiftDay(int days) => setEventDate(addDays(eventDate, days));
  void setStartMin(int v) => _set(() => startMin = v);
  void stepTime({required bool forward}) =>
      setStartMin(snapQuarter(startMin, forward: forward));
  void setPresetDuration(int? secs) => _set(() => presetDuration = secs);
  void setCustomDuration(String v) => _set(() => customDuration = v);

  /// Pick the target note. Callers unlock gated files first.
  void pickFile(NoteFileDto file) => _set(() {
    target = file;
    targetHeader = null;
  });

  void pickHeader(String? header) => _set(() => targetHeader = header);

  void clearTarget() => _set(() {
    target = null;
    targetHeader = null;
  });

  /// Event defaults: today, next quarter hour.
  void resetEventTime() {
    final now = _clock();
    eventDate = dayOf(now);
    startMin = snapQuarter(now.hour * 60 + now.minute, forward: true);
  }

  /// Back to a fresh form; mode stays, every other choice resets.
  void clearDraft() => _set(() {
    title = '';
    body = '';
    target = null;
    targetHeader = null;
    priority = Priority.medium;
    weekly = false;
    presetDuration = 45 * 60;
    customDuration = '';
    resetEventTime();
  });

  Future<void> reload() async {
    try {
      _projects = await _notes.projects();
    } on AppFailure catch (e) {
      notice = e.message;
    }
    _notify();
  }

  /// Submit the draft. Returns true on success (draft cleared, [notice] set).
  Future<bool> save() async {
    if (!canSave) return false;
    _set(() => saving = true);
    try {
      notice = await _submit();
      clearDraft();
      return true;
    } on AppFailure catch (e) {
      notice = e.message;
      return false;
    } finally {
      _set(() => saving = false);
    }
  }

  Future<String> _submit() async {
    switch (mode) {
      case CaptureMode.note:
        final path = await _notes.capture(
          NoteCapture(
            title: title,
            body: body,
            notePath: target?.relPath,
            header: targetHeader,
          ),
        );
        return 'Saved to $path';
      case CaptureMode.agent:
        final path = await _notes.delegate(
          AgentTask(
            title: title,
            body: body,
            priority: priority,
            project: target?.relPath,
          ),
        );
        return 'Sent to $path';
      case CaptureMode.event:
        await _saveEvent();
        return 'Event added';
    }
  }

  Future<void> _saveEvent() async {
    final event = EventDto(
      title: title.trim(),
      dateIso: isoOf(eventDate),
      startMin: startMin,
      durationSecs: durationSecs!,
      context: body.trim(),
      source: weekly ? EventSource.weekly : EventSource.day,
      index: 0,
    );
    await _events.add(event);
    try {
      await _onEventSaved?.call(event);
    } on AppFailure catch (e) {
      // The event is saved; only the optional alarm failed.
      debugPrint('auto alarm skipped: ${e.message}');
    }
  }

  void _onRevision() => unawaited(reload());

  void _set(void Function() change) {
    change();
    _notify();
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
