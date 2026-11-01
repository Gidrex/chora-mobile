import 'models.dart';
import 'vault_session.dart';

/// Notes and captures. Caches reads until the session [VaultSession.revision]
/// moves; every write goes through [VaultSession.write] and bumps it.
class NotesRepository {
  NotesRepository(this._session) {
    _session.revision.addListener(_clear);
  }

  final VaultSession _session;
  Future<List<ProjectDto>>? _projects;
  final _notes = <String, Future<NoteDto>>{};

  void _clear() {
    _projects = null;
    _notes.clear();
  }

  Future<List<ProjectDto>> projects() =>
      _projects ??= _uncachedOnError(_session.read((v) => v.projects()), () {
        _projects = null;
      });

  Future<NoteDto> note(String relPath) => _notes[relPath] ??= _uncachedOnError(
    _session.read((v) => v.readNote(relPath: relPath)),
    () => _notes.remove(relPath),
  );

  /// Overwrite [relPath]; [base] is the text the edit started from.
  Future<void> save(String relPath, String text, {required String base}) =>
      _session.write(
        (v) => v.saveNote(relPath: relPath, text: text, base: base),
      );

  /// Flip the task on raw [line] of [base]; returns the new text.
  Future<String> toggleTask(String relPath, int line, {required String base}) =>
      _session.write(
        (v) => v.toggleTask(relPath: relPath, line: line, base: base),
      );

  /// Append to a note; returns the path relative to the notes root.
  Future<String> capture(NoteCapture capture) =>
      _session.write((v) => v.captureNote(capture: capture));

  /// Task file for the agent; returns the path relative to the storage root.
  Future<String> delegate(AgentTask task) =>
      _session.write((v) => v.delegate(task: task));

  void dispose() => _session.revision.removeListener(_clear);
}

/// Cache the future, but forget it when it fails so the next call retries.
Future<T> _uncachedOnError<T>(Future<T> future, void Function() forget) =>
    future.catchError((Object e) {
      forget();
      throw e;
    });
