import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'backend.dart';

/// Reminders before events + optional system alarm intents.
class Reminders {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  /// Re-plan reminders for yesterday..day-after-tomorrow (cheap reboot-proofing).
  /// Asks for the notification permission only when something is actually due.
  static Future<void> rescheduleUpcoming({
    required bool enabled,
    required int minutesBefore,
  }) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!enabled) return;
    final now = DateTime.now();
    final pending = <({int id, String title, String body, DateTime start})>[];
    for (var offset = -1; offset <= 2; offset++) {
      final day = now.add(Duration(days: offset));
      final iso = Backend.isoOf(day);
      DayEventsDto dto;
      try {
        dto = await getDayEvents(rootDir: Backend.root, dateIso: iso);
      } catch (_) {
        continue;
      }
      for (final event in dto.events) {
        if (event.isRepeatable) continue;
        final id = '$iso#${event.index}'.hashCode & 0x7fffffff;
        final parts = event.timeHhmm.split(':');
        if (parts.length != 2) continue;
        final start = DateTime(
          day.year,
          day.month,
          day.day,
          int.tryParse(parts[0]) ?? 0,
          int.tryParse(parts[1]) ?? 0,
        ).subtract(Duration(minutes: minutesBefore));
        if (start.isBefore(now)) continue;
        final when = minutesBefore == 0
            ? 'starting now'
            : 'in $minutesBefore min';
        pending.add((
          id: id,
          title: '${event.title} ($iso)',
          body: '$when at ${event.timeHhmm}',
          start: start,
        ));
      }
    }
    if (pending.isEmpty) return;
    if (!await Permission.notification.request().isGranted) return;
    for (final item in pending) {
      try {
        await _plugin.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          scheduledDate: tz.TZDateTime.from(item.start, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'chora_events',
              'Event reminders',
              importance: Importance.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (_) {
        // Scheduling is best-effort (exact-alarm policy, OEM quirks).
      }
    }
  }

  /// Automatic system alarm after an event is saved.
  /// `first` = earliest event of the day, `tag` = title/context has `#alarm`.
  /// Fires [beforeMin] minutes before the start, best-effort.
  static Future<void> maybeAutoAlarm({
    required bool enabled,
    required String mode,
    required int beforeMin,
    required EventDto event,
  }) async {
    if (!enabled || event.isRepeatable) return;
    if (mode == 'tag' &&
        !'${event.title} ${event.context}'.contains('#alarm')) {
      return;
    }
    if (mode == 'first') {
      try {
        final day = await getDayEvents(
          rootDir: Backend.root,
          dateIso: event.dateIso,
        );
        final times = [
          for (final e in day.events)
            if (!e.isRepeatable) e.timeHhmm,
        ]..sort();
        if (times.isEmpty || event.timeHhmm != times.first) return;
      } catch (_) {
        return;
      }
    }
    final parts = event.timeHhmm.split(':');
    if (parts.length != 2) return;
    final day = Backend.dateOf(event.dateIso);
    final start = DateTime(
      day.year,
      day.month,
      day.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
    final alarm = start.subtract(Duration(minutes: beforeMin));
    if (alarm.isBefore(DateTime.now())) return;
    try {
      await setSystemAlarm(
        title: event.title,
        hour: alarm.hour,
        minute: alarm.minute,
      );
    } catch (_) {
      // Alarm clock app missing or denied: reminders still cover it.
    }
  }

  /// Fire-and-forget system alarm for one event (`AlarmClock.SET_ALARM`).
  static Future<void> setSystemAlarm({
    required String title,
    required int hour,
    required int minute,
  }) async {
    await AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: {
        'android.intent.extra.alarm.HOUR': hour,
        'android.intent.extra.alarm.MINUTES': minute,
        'android.intent.extra.alarm.MESSAGE': title,
        'android.intent.extra.alarm.SKIP_UI': true,
      },
    ).launch();
  }
}
