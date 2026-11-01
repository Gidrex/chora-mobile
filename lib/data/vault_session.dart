import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart'
    show PanicException;

import '../src/rust/api/error.dart';
import '../src/rust/api/vault.dart';

export '../src/rust/api/error.dart' show ErrorKind;

/// User-ready failure from any repository. Widgets show [message];
/// controllers branch on [kind] (e.g. [ErrorKind.changed] -> reload).
class AppFailure implements Exception {
  const AppFailure(this.kind, this.message);

  final ErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// The open storage plus one app-wide [revision]. Every write and every
/// external change (sync) bumps it; repositories drop caches and controllers
/// reload on a bump. The only Dart object that holds the bridge [Vault].
class VaultSession {
  VaultSession._(this._vault, this._stamp);

  Vault _vault;
  BigInt? _stamp;

  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  /// Bumped after writes, storage switches and detected external changes.
  ValueListenable<int> get revision => _revision;

  /// Absolute storage path.
  String get root => _vault.root;

  /// Open the storage at [root]; throws [AppFailure].
  static Future<VaultSession> open(String root) async {
    final vault = await _guard(() => Vault.open(root: root));
    return VaultSession._(vault, null);
  }

  /// Switch to another storage path. The old one stays open on failure.
  Future<void> reopen(String root) async {
    _vault = await _guard(() => Vault.open(root: root));
    _stamp = null;
    _revision.value++;
  }

  /// Read through the bridge; errors become [AppFailure].
  Future<T> read<T>(Future<T> Function(Vault vault) call) =>
      _guard(() => call(_vault));

  /// Write through the bridge, then bump [revision].
  Future<T> write<T>(Future<T> Function(Vault vault) call) async {
    final result = await _guard(() => call(_vault));
    // Our own write is not an external change: re-baseline the stamp.
    _stamp = await _guard(() => _vault.stamp());
    _revision.value++;
    return result;
  }

  /// Bump [revision] when files changed outside the app since the last check
  /// (Syncthing). Cheap: metadata only. Returns true when it bumped.
  Future<bool> refreshIfChanged() async {
    final next = await _guard(() => _vault.stamp());
    final changed = _stamp != null && _stamp != next;
    _stamp = next;
    if (changed) _revision.value++;
    return changed;
  }

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiError catch (e) {
      throw AppFailure(e.kind, e.message);
    } on PanicException catch (e) {
      throw AppFailure(ErrorKind.io, 'Internal error: ${e.message}');
    }
  }
}
