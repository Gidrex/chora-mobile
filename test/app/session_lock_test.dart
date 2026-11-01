import 'package:chora_mobile/app/session_lock.dart';
import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/domain/security.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsStore settings;
  var now = DateTime(2026, 11, 2, 10);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsStore(await SharedPreferences.getInstance());
    await settings.setSecurityThreshold(SecurityThreshold.open);
  });

  test('unlock grants a clearance up to its level', () {
    final lock = SessionLock(settings, clock: () => now);
    expect(lock.appLocked, isTrue);
    lock.grant(SecurityLevel.restricted);
    expect(lock.appLocked, isFalse);
    expect(lock.locked(SecurityLevel.restricted), isFalse);
    expect(lock.locked(SecurityLevel.critical), isTrue);
  });

  test('relocks only after a long pause', () {
    final lock = SessionLock(settings, clock: () => now)
      ..grant(SecurityLevel.critical)
      ..paused();
    now = now.add(const Duration(seconds: 30));
    lock.resumed();
    expect(lock.appLocked, isFalse);
    lock.paused();
    now = now.add(SessionLock.relockAfter + const Duration(seconds: 1));
    lock.resumed();
    expect(lock.appLocked, isTrue);
  });
}
