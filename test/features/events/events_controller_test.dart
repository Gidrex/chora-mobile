import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/features/events/events_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_events_repository.dart';

void main() {
  late FakeEventsRepository repo;
  late SettingsStore settings;
  late ValueNotifier<int> revision;
  late List<EventDto> alarms;
  late int refreshes;
  late EventsController c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsStore(await SharedPreferences.getInstance());
    repo = FakeEventsRepository();
    revision = ValueNotifier(0);
    alarms = [];
    refreshes = 0;
    c = EventsController(
      repo,
      settings,
      revision,
      afterSave: (e) async => alarms.add(e),
      refresh: () async => refreshes++,
      clock: () => DateTime(2026, 11, 2, 9),
    );
  });

  tearDown(() => c.dispose());

  test(
    'month view loads grid and selected day; agenda loads 14 days',
    () async {
      await c.load();
      expect(repo.calls, ['month 11', 'day 2']);
      repo.calls.clear();
      await c.setView(EventsView.agenda);
      expect(settings.eventsView, EventsView.agenda);
      expect(repo.calls, ['range 2-15']);
    },
  );

  test('selecting a day in another month pages the grid', () async {
    c.select(DateTime(2026, 12, 3));
    await pumpEventQueue();
    expect(c.month, DateTime(2026, 12));
    expect(repo.calls, ['month 12', 'day 3']);
  });

  test('save adds, updates and rings the alarm hook', () async {
    expect(await c.save(updated: ev('A')), isNull);
    expect(await c.save(original: ev('A'), updated: ev('B')), isNull);
    expect(repo.stored.map((e) => e.title), ['B']);
    await pumpEventQueue();
    expect(alarms.map((e) => e.title), ['A', 'B']);
  });

  test('changed-on-disk refreshes and returns the stale message', () async {
    repo.failWrite = const AppFailure(ErrorKind.changed, 'changed');
    expect(await c.delete(ev('A')), EventsController.changedMessage);
    expect(refreshes, 1);
    repo.failWrite = const AppFailure(ErrorKind.invalid, 'event needs a title');
    expect(await c.save(updated: ev('')), 'event needs a title');
    expect(alarms, isEmpty);
  });

  test('revision bump reloads and advances generation', () async {
    revision.value++;
    await pumpEventQueue();
    expect(c.generation, 1);
    expect(repo.calls, ['month 11', 'day 2']);
  });
}
