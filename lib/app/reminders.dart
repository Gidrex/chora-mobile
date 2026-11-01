import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/events_repository.dart';
import '../data/models.dart';
import '../data/settings_store.dart';
import '../data/vault_session.dart';
import '../domain/dates.dart';
import '../domain/reminders.dart';
import '../platform/notifications.dart';

/// Keeps scheduled reminders in step with storage and settings, and rings
/// the optional system alarm after an event is saved.
class Reminders {
  Reminders(this._events, this._settings, this._session, this._notifier);

  /// How far ahead reminders are planned.
  static const horizonDays = 14;

  final EventsRepository _events;
  final SettingsStore _settings;
  final VaultSession _session;
  final Notifier _notifier;
  Timer? _debounce;

  /// Start following changes; plans once right away.
  void start() {
    _session.revision.addListener(_schedule);
    _settings.addListener(_schedule);
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 800),
      () => unawaited(sync()),
    );
  }

  Future<void> sync() async {
    try {
      if (!_settings.remindersEnabled) {
        await _notifier.replaceAll(const []);
        return;
      }
      final now = DateTime.now();
      final events = await _events.range(dayOf(now), addDays(now, horizonDays));
      await _notifier.replaceAll(
        planReminders(
          events,
          now: now,
          minutesBefore: _settings.reminderMinutes,
        ),
      );
    } on AppFailure catch (e) {
      // Background job: the screens show storage errors themselves.
      debugPrint('reminders not planned: ${e.message}');
    }
  }

  /// System alarm for a just-saved event, when the user enabled it.
  Future<void> afterSave(EventDto saved) async {
    if (!_settings.autoAlarm) return;
    final day = await _events.day(dateOf(saved.dateIso));
    final at = autoAlarmAt(
      saved,
      day,
      mode: _settings.alarmMode,
      minutesBefore: _settings.alarmMinutes,
      now: DateTime.now(),
    );
    if (at != null) await _notifier.setAlarm(title: saved.title, at: at);
  }

  void dispose() {
    _debounce?.cancel();
    _session.revision.removeListener(_schedule);
    _settings.removeListener(_schedule);
  }
}
