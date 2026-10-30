import 'package:flutter/foundation.dart';

import '../backend.dart';

/// User-ready failure from [NotesRepository]. The repository maps bridge
/// errors to messages once (`Backend.errMsg`); controllers and widgets just
/// render [message] without importing the bridge.
class NotesFailure implements Exception {
  const NotesFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Notes over the bridge with a read cache and a write [revision].
/// Widgets never call the bridge directly; they go through a controller
/// that listens to [revision] and refreshes on every bump.
abstract class NotesRepository {
  /// Bumped after every write performed through this repository and on
  /// every [invalidate] call.
  ValueListenable<int> get revision;

  /// Drop caches and bump [revision] (Syncthing may have changed files).
  Future<void> invalidate();

  Future<List<ProjectDto>> projects();
  Future<NoteContentDto> readNote(String relPath);
  Future<void> saveNote(String relPath, String body);
  Future<String> toggleCheckbox(String relPath, int lineIndex);
}

class BridgeNotesRepository implements NotesRepository {
  final _revision = ValueNotifier<int>(0);
  List<ProjectDto>? _projectsCache;
  final _noteCache = <String, NoteContentDto>{};

  @override
  ValueListenable<int> get revision => _revision;

  void _bump() {
    _projectsCache = null;
    _noteCache.clear();
    _revision.value++;
  }

  @override
  Future<void> invalidate() async {
    _projectsCache = null;
    _noteCache.clear();
    _revision.value++;
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      throw NotesFailure(Backend.errMsg(e));
    }
  }

  @override
  Future<List<ProjectDto>> projects() async {
    final cached = _projectsCache;
    if (cached != null) return cached;
    final fresh = await _guard(() => listAllProjects(rootDir: Backend.root));
    _projectsCache = fresh;
    return fresh;
  }

  @override
  Future<NoteContentDto> readNote(String relPath) async {
    final cached = _noteCache[relPath];
    if (cached != null) return cached;
    final content = await _guard(
      () => readNoteFile(rootDir: Backend.root, relPath: relPath),
    );
    _noteCache[relPath] = content;
    return content;
  }

  @override
  Future<void> saveNote(String relPath, String body) async {
    await _guard(
      () =>
          saveNoteFile(rootDir: Backend.root, relPath: relPath, newBody: body),
    );
    _bump();
  }

  @override
  Future<String> toggleCheckbox(String relPath, int lineIndex) async {
    final updated = await _guard(
      () => toggleMarkdownCheckbox(
        rootDir: Backend.root,
        relPath: relPath,
        lineIndex: BigInt.from(lineIndex),
      ),
    );
    _bump();
    return updated;
  }
}
