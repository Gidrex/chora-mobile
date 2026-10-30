import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/settings_store.dart';
import '../../data/models.dart';
import '../../data/notes_repository.dart';

/// Notes screen state: project list + one open file. Owns loaded data,
/// `loading` and `error`; ephemeral UI (filter text, expansion, edit text)
/// stays in the widgets. No `BuildContext`: errors surface as values.
class NotesController extends ChangeNotifier {
  NotesController(this._repo, this._state) {
    _repo.revision.addListener(_onRevision);
  }

  final NotesRepository _repo;
  final SettingsStore _state;
  bool _disposed = false;

  /// notifyListeners that survives async gaps racing with dispose.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  List<ProjectDto> _projects = const [];
  bool loading = true;
  String? error;
  String filter = '';
  bool showHidden = false;

  NoteFileDto? openFile;
  String? fileText;
  bool fileLoading = false;
  String? fileError;

  /// One-shot user message (`Saved`, error text); widgets render and clear.
  String? notice;
  void consumeNotice() {
    notice = null;
  }

  SettingsStore get state => _state;

  /// All project dirs (for the visibility sheet), including hidden ones.
  List<String> get allDirs =>
      _projects.map((p) => p.dir).where((d) => d != '(files)').toList();

  /// Projects minus hidden ones (unless [showHidden]), matching [filter]
  /// against the dir or any file path, like the old list did.
  List<ProjectDto> get visibleProjects {
    final hidden = _state.hiddenProjects.toSet();
    final q = filter.trim().toLowerCase();
    return [
      for (final p in _projects)
        if ((!hidden.contains(p.dir) || showHidden) &&
            (q.isEmpty ||
                p.dir.toLowerCase().contains(q) ||
                p.files.any((f) => f.relPath.toLowerCase().contains(q))))
          p,
    ];
  }

  void toggleHidden() {
    showHidden = !showHidden;
    _notify();
  }

  void setFilter(String value) {
    if (filter == value) return;
    filter = value;
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

  Future<void> open(NoteFileDto file) async {
    openFile = file;
    fileText = null;
    fileError = null;
    fileLoading = true;
    _notify();
    try {
      fileText = (await _repo.readNote(file.relPath)).text;
    } on NotesFailure catch (e) {
      fileError = e.message;
    }
    fileLoading = false;
    _notify();
  }

  Future<bool> saveFile(String body) async {
    final file = openFile;
    if (file == null) return false;
    try {
      await _repo.saveNote(file.relPath, body);
      fileText = body;
      notice = 'Saved';
      _notify();
      return true;
    } on NotesFailure catch (e) {
      notice = e.message;
      _notify();
      return false;
    }
  }

  Future<void> toggleLine(int lineIndex) async {
    final file = openFile;
    if (file == null) return;
    try {
      fileText = await _repo.toggleCheckbox(file.relPath, lineIndex);
      _notify();
    } on NotesFailure catch (e) {
      notice = e.message;
      _notify();
    }
  }

  void _onRevision() {
    // Another writer changed data: refresh list and the open file quietly.
    unawaited(reload());
    final file = openFile;
    if (file != null) unawaited(_refreshFile(file));
  }

  Future<void> _refreshFile(NoteFileDto file) async {
    try {
      fileText = (await _repo.readNote(file.relPath)).text;
      _notify();
    } catch (_) {
      // Keep the last good text; the list reload surfaces errors.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _repo.revision.removeListener(_onRevision);
    super.dispose();
  }
}
