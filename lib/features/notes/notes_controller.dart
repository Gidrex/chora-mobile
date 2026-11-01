import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/notes_repository.dart';
import '../../data/settings_store.dart';
import '../../domain/notes_filter.dart';
import '../../domain/notes_tree.dart';

/// Notes tree state: loaded projects, search query, folder open/closed
/// toggles, load/error flags.
/// Reloads whenever the storage [revision] moves.
class NotesController extends ChangeNotifier {
  NotesController(this._repo, this._settings, this._revision) {
    _revision.addListener(_onRevision);
    _settings.addListener(notifyListeners);
  }

  final NotesRepository _repo;
  final SettingsStore _settings;
  final Listenable _revision;
  bool _disposed = false;

  List<ProjectDto> _projects = const [];
  bool loading = true;
  String? error;
  String query = '';
  final _toggled = <String>{};

  /// Projects after hiding and searching.
  List<ProjectDto> get visible => filterProjects(
    _projects,
    query: query,
    hidden: _settings.hiddenProjects.toSet(),
  );

  /// One tree per visible project; search opens every folder on the way.
  List<List<TreeRow>> get trees => [
    for (final p in visible)
      projectRows(p, toggled: _toggled, expandAll: query.trim().isNotEmpty),
  ];

  /// Open or close the folder at tree [path].
  void toggle(String path) {
    if (!_toggled.remove(path)) _toggled.add(path);
    _notify();
  }

  /// Names of every real project (for the visibility sheet).
  List<String> get projectNames => [
    for (final p in _projects)
      if (!p.isLoose) p.name,
  ];

  void setQuery(String value) {
    if (query == value) return;
    query = value;
    _notify();
  }

  Future<void> reload() async {
    loading = true;
    error = null;
    _notify();
    try {
      _projects = await _repo.projects();
    } on AppFailure catch (e) {
      error = e.message;
    }
    loading = false;
    _notify();
  }

  void _onRevision() => unawaited(reload());

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision.removeListener(_onRevision);
    _settings.removeListener(notifyListeners);
    super.dispose();
  }
}
