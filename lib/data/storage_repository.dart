import 'models.dart';
import 'vault_session.dart';

/// Storage maintenance: location, sync conflicts, old events, demo content.
class StorageRepository {
  StorageRepository(this._session);

  final VaultSession _session;

  String get root => _session.root;

  /// Switch the storage folder; the old one stays open on failure.
  Future<void> moveTo(String root) => _session.reopen(root);

  Future<List<ConflictDto>> conflicts() => _session.read((v) => v.conflicts());

  Future<void> resolve(ConflictDto conflict, ConflictChoice choice) => _session
      .write((v) => v.resolveConflict(path: conflict.path, choice: choice));

  Future<SweepDto> sweep(OldEventPolicy policy) =>
      _session.write((v) => v.sweepOldEvents(policy: policy));

  /// False when the storage already has notes (nothing written).
  Future<bool> seedDemo() => _session.write((v) => v.seedDemo());
}
