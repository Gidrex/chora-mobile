import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/settings_store.dart';
import '../domain/security.dart';

/// Session-only unlock state. A successful unlock grants a clearance level:
/// every note at or below it stays open until the app sits in the
/// background longer than [relockAfter]. Never persisted.
class SessionLock extends ChangeNotifier {
  SessionLock(this._settings, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const relockAfter = Duration(seconds: 60);

  final SettingsStore _settings;
  final DateTime Function() _clock;
  SecurityLevel? _clearance;
  DateTime? _pausedAt;

  SecurityThreshold get threshold => _settings.securityThreshold;

  /// The whole app is behind the lock screen.
  bool get appLocked =>
      threshold == SecurityThreshold.open && _clearance == null;

  /// True when a note of [level] must be unlocked before it is shown.
  bool locked(SecurityLevel level) =>
      needsGate(level, threshold) &&
      (_clearance == null || level.index > _clearance!.index);

  /// Record a successful unlock for [level].
  void grant(SecurityLevel level) {
    if (_clearance != null && _clearance!.index >= level.index) return;
    _clearance = level;
    notifyListeners();
  }

  void paused() => _pausedAt = _clock();

  void resumed() {
    final at = _pausedAt;
    _pausedAt = null;
    if (at == null || _clearance == null) return;
    if (_clock().difference(at) > relockAfter) {
      _clearance = null;
      notifyListeners();
    }
  }
}
