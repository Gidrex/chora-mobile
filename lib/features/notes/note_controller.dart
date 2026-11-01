import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/notes_repository.dart';
import '../../domain/markdown_tasks.dart';

/// One open note: its text on disk, saves and task toggles. Every write
/// carries the text it started from so sync changes are never overwritten.
class NoteController extends ChangeNotifier {
  NoteController(this._repo, this._revision, this.relPath) {
    _revision.addListener(_onRevision);
  }

  final NotesRepository _repo;
  final Listenable _revision;
  final String relPath;
  bool _disposed = false;
  bool _toggling = false;

  /// Text as last read or written; null until the first load.
  String? text;
  String? error;
  bool saving = false;

  /// One-shot message for a snackbar; the screen clears it after showing.
  String? notice;

  Future<void> load() async {
    error = null;
    try {
      text = (await _repo.note(relPath)).text;
    } on AppFailure catch (e) {
      error = e.message;
    }
    _notify();
  }

  /// Write [edited] over [base]. True on success. On a sync conflict the
  /// note reloads and the caller keeps the edits for a second save.
  Future<bool> save(String edited, {required String base}) async {
    saving = true;
    _notify();
    try {
      await _repo.save(relPath, edited, base: base);
      text = edited;
      notice = 'Saved';
      return true;
    } on AppFailure catch (e) {
      notice = e.kind == ErrorKind.changed
          ? 'Changed on another device. Your edits are kept, save again to overwrite.'
          : e.message;
      if (e.kind == ErrorKind.changed) await load();
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  /// Flip the task on raw [line] at once, then persist; reverts on failure.
  Future<void> toggle(int line) async {
    final base = text;
    final flipped = base == null ? null : flipTask(base, line);
    // One write at a time: a second tap would race on a stale base.
    if (base == null || flipped == null || _toggling) return;
    text = flipped;
    _toggling = true;
    _notify();
    try {
      text = await _repo.toggleTask(relPath, line, base: base);
    } on AppFailure catch (e) {
      text = base;
      if (e.kind == ErrorKind.changed) {
        notice = 'Changed on another device, reloaded';
        await load();
      } else {
        notice = e.message;
      }
    } finally {
      _toggling = false;
      _notify();
    }
  }

  void _onRevision() {
    // Our own toggle bumps the revision too; its result is already in [text].
    if (!_toggling && !saving) unawaited(load());
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
