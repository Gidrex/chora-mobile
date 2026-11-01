import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models.dart';
import '../../data/storage_repository.dart';

/// Storage folder, sync conflicts and past-event cleanup. Reloads conflicts
/// whenever the storage revision moves (writes, sync, folder switch).
/// Intent methods return the line to show the user.
class StorageController extends ChangeNotifier {
  StorageController(this._storage, this._revision) {
    _revision.addListener(_onRevision);
  }

  final StorageRepository _storage;
  final Listenable _revision;
  bool _disposed = false;

  List<ConflictDto> conflicts = const [];
  String? error;

  String get root => _storage.root;

  Future<void> load() async {
    try {
      conflicts = await _storage.conflicts();
      error = null;
    } on AppFailure catch (e) {
      error = e.message;
    }
    _notify();
  }

  Future<String> resolve(ConflictDto conflict, ConflictChoice choice) =>
      _run(() async {
        await _storage.resolve(conflict, choice);
        return choice == ConflictChoice.keepCurrent
            ? 'Kept the current file'
            : 'Kept the conflict copy';
      });

  /// Switch the storage folder; returns null on success.
  Future<String?> moveTo(String path) async {
    try {
      await _storage.moveTo(path);
      return null;
    } on AppFailure catch (e) {
      return e.message;
    }
  }

  Future<String> sweep(OldEventPolicy policy) => _run(() async {
    final report = await _storage.sweep(policy);
    final n = report.deleted + report.backlogged;
    if (n == 0) return 'No past days to clean up';
    final verb = policy == OldEventPolicy.delete ? 'Deleted' : 'Archived';
    return '$verb $n ${n == 1 ? 'day' : 'days'}';
  });

  Future<String> _run(Future<String> Function() call) async {
    try {
      return await call();
    } on AppFailure catch (e) {
      return e.message;
    }
  }

  void _onRevision() => unawaited(load());

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

/// `/storage/emulated/0/Sync/chora` -> `Internal storage/Sync/chora`.
String friendlyPath(String path, {required bool isDefault}) {
  if (isDefault) return 'App folder (private)';
  const primary = '/storage/emulated/0/';
  return path.startsWith(primary)
      ? 'Internal storage/${path.substring(primary.length)}'
      : path;
}
