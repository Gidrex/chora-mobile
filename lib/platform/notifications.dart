import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminders.dart';

/// Android notifications for event reminders and system alarm intents.
class Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  Future<void> _init() => _ready ??= () async {
    // Instants are converted as-is, so the default UTC location is correct.
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }();

  /// Replace every scheduled reminder with [plan]. Asks for the
  /// notification permission only when something is due.
  Future<void> replaceAll(List<PlannedReminder> plan) async {
    await _init();
    await _plugin.cancelAll();
    if (plan.isEmpty) return;
    if (!await Permission.notification.request().isGranted) return;
    for (final r in plan) {
      try {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'chora_events',
              'Event reminders',
              importance: Importance.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } on PlatformException catch (e) {
        // One rejected alarm (OEM limits) must not drop the rest.
        debugPrint('reminder ${r.id} not scheduled: ${e.message}');
      }
    }
  }

  /// System clock alarm (`AlarmClock.SET_ALARM`) without opening the clock UI.
  Future<void> setAlarm({required String title, required DateTime at}) =>
      AndroidIntent(
        action: 'android.intent.action.SET_ALARM',
        arguments: {
          'android.intent.extra.alarm.HOUR': at.hour,
          'android.intent.extra.alarm.MINUTES': at.minute,
          'android.intent.extra.alarm.MESSAGE': title,
          'android.intent.extra.alarm.SKIP_UI': true,
        },
      ).launch();
}
