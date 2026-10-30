import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/data/events_repository.dart';
import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/data/notes_repository.dart';
import 'package:chora_mobile/features/events/events_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeEventsRepository implements EventsRepository {
  FakeEventsRepository(this.days);

  final Map<String, DayEventsDto> days;
  final Map<String, List<EventDto>> repeatableDays = {};
  final _revision = ValueNotifier<int>(0);
  int monthCalls = 0;

  @override
  ValueListenable<int> get revision => _revision;

  @override
  Future<void> invalidate() async {
    _revision.value++;
  }

  @override
  Future<List<CalendarCellDto>> monthGrid(
    int year,
    int month, {
    required bool showRepeat,
  }) async {
    monthCalls++;
    return const [];
  }

  @override
  Future<DayEventsDto> dayEvents(String dateIso) async {
    final day = days[dateIso];
    if (day == null) throw const NotesFailure('no such day');
    return day;
  }

  void _bump() => _revision.value++;

  @override
  Future<void> createEvent(EventDto event) async {
    final day =
        days[event.dateIso] ?? const DayEventsDto(rawMarkdown: '', events: []);
    days[event.dateIso] = DayEventsDto(
      rawMarkdown: day.rawMarkdown,
      events: [...day.events, event],
    );
    _bump();
  }

  @override
  Future<void> updateEvent(
    String originalDateIso,
    BigInt sectionIndex,
    EventDto updated,
  ) async {
    _bump();
  }

  @override
  Future<void> deleteEvent(String dateIso, BigInt sectionIndex) async {
    _bump();
  }

  @override
  Future<List<EventDto>> repeatables(String weekday) async {
    return repeatableDays[weekday] ?? const [];
  }

  @override
  Future<void> saveRepeatables(String weekday, List<EventDto> events) async {
    repeatableDays[weekday] = events;
    _bump();
  }
}

EventDto _event(String title) => EventDto(
  index: BigInt.zero,
  title: title,
  dateIso: '2026-10-30',
  timeHhmm: '09:00',
  durationStr: '30m',
  context: '',
  isRepeatable: false,
);

void main() {
  test('reload fills month and repeatables', () async {
    SharedPreferences.setMockInitialValues({});
    final state = SettingsStore(
      await SharedPreferences.getInstance(),
      AppearanceSettings(await SharedPreferences.getInstance()),
    );
    final controller = EventsController(FakeEventsRepository({}), state);
    await controller.reload();
    expect(controller.monthLoading, isFalse);
    expect(controller.repeatLoading, isFalse);
    expect(controller.error, isNull);
    controller.dispose();
  });

  test('setRepeatDay reloads and upsert renumbers', () async {
    SharedPreferences.setMockInitialValues({});
    final state = SettingsStore(
      await SharedPreferences.getInstance(),
      AppearanceSettings(await SharedPreferences.getInstance()),
    );
    final repo = FakeEventsRepository({});
    final controller = EventsController(repo, state);
    await controller.reload();
    controller.setRepeatDay('tuesday');
    expect(controller.repeatDay, 'tuesday');
    await controller.upsertRepeatable(
      existing: null,
      index: null,
      dto: _event('Gym'),
    );
    final saved = repo.repeatableDays['tuesday']!;
    expect(saved, hasLength(1));
    expect(saved.first.isRepeatable, isTrue);
    await controller.upsertRepeatable(
      existing: saved.first,
      index: 0,
      dto: _event('Gym late'),
    );
    expect(repo.repeatableDays['tuesday']!.first.title, 'Gym late');
    await controller.deleteRepeatable(0);
    expect(repo.repeatableDays['tuesday'], isEmpty);
    controller.dispose();
  });

  test('revision triggers reload', () async {
    SharedPreferences.setMockInitialValues({});
    final state = SettingsStore(
      await SharedPreferences.getInstance(),
      AppearanceSettings(await SharedPreferences.getInstance()),
    );
    final repo = FakeEventsRepository({});
    final controller = EventsController(repo, state);
    await controller.reload();
    final before = repo.monthCalls;
    await repo.createEvent(_event('Standup'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.monthCalls, greaterThan(before));
    controller.dispose();
  });
}
