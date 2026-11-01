import 'package:shared_preferences/shared_preferences.dart';

import '../data/events_repository.dart';
import '../data/notes_repository.dart';
import '../data/settings_store.dart';
import '../data/storage_repository.dart';
import '../data/vault_session.dart';
import '../platform/notifications.dart';
import '../platform/paths.dart';
import '../platform/pin_store.dart';
import 'reminders.dart';
import 'session_lock.dart';

/// Composition root: every long-lived object, created once at boot and
/// handed to widgets through `AppScope`. Add new services here.
class AppServices {
  AppServices({
    required this.settings,
    required this.session,
    this.pins = const PinStore(),
    Notifier? notifier,
  }) : notes = NotesRepository(session),
       events = EventsRepository(session),
       storage = StorageRepository(session),
       lock = SessionLock(settings) {
    reminders = Reminders(events, settings, session, notifier ?? Notifier());
  }

  final SettingsStore settings;
  final VaultSession session;
  final PinStore pins;
  final NotesRepository notes;
  final EventsRepository events;
  final StorageRepository storage;
  final SessionLock lock;
  late final Reminders reminders;

  /// Load prefs and open the storage. Throws [AppFailure] when the
  /// configured folder cannot be opened.
  static Future<AppServices> boot(SharedPreferences prefs) async {
    final settings = SettingsStore(prefs);
    final path = settings.storagePath ?? await defaultStoragePath();
    final session = await VaultSession.open(path);
    return AppServices(settings: settings, session: session);
  }
}
