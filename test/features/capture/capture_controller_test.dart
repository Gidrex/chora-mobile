import 'package:chora_mobile/data/events_repository.dart';
import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/data/notes_repository.dart';
import 'package:chora_mobile/data/settings_store.dart';
import 'package:chora_mobile/features/capture/capture_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _secret = NoteFileDto(
  relPath: 'vault/secrets.md',
  name: 'secrets.md',
  title: '',
  security: SecurityLevel.restricted,
  about: '',
  headers: ['Passwords'],
);
const _todo = NoteFileDto(
  relPath: 'work/todo.md',
  name: 'todo.md',
  title: 'Todo',
  security: SecurityLevel.open,
  about: 'Todo',
  headers: ['Todo', 'Tasks'],
);

class FakeNotes extends Fake implements NotesRepository {
  final captures = <NoteCapture>[];
  final tasks = <AgentTask>[];

  @override
  Future<List<ProjectDto>> projects() async => const [
    ProjectDto(
      name: 'vault',
      isLoose: false,
      security: SecurityLevel.restricted,
      about: '',
      files: [_secret],
    ),
    ProjectDto(
      name: 'work',
      isLoose: false,
      security: SecurityLevel.open,
      about: '',
      files: [_todo],
    ),
  ];

  @override
  Future<String> capture(NoteCapture capture) async {
    captures.add(capture);
    return capture.notePath ?? 'inbox.md';
  }

  @override
  Future<String> delegate(AgentTask task) async {
    tasks.add(task);
    return 'to-agent/2026-11-02-x.md';
  }
}

class FakeEvents extends Fake implements EventsRepository {
  final added = <EventDto>[];

  @override
  Future<void> add(EventDto event) async => added.add(event);
}

void main() {
  late FakeNotes notes;
  late FakeEvents events;
  late SettingsStore settings;
  final unlocked = <SecurityLevel>{};
  final saved = <EventDto>[];

  CaptureController controller() => CaptureController(
    notes: notes,
    events: events,
    settings: settings,
    locked: (level) => level != SecurityLevel.open && !unlocked.contains(level),
    revision: ValueNotifier(0),
    onEventSaved: (e) async => saved.add(e),
    clock: () => DateTime(2026, 11, 2, 9, 7),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsStore(await SharedPreferences.getInstance());
    notes = FakeNotes();
    events = FakeEvents();
    unlocked.clear();
    saved.clear();
  });

  test('note goes under the picked section', () async {
    final c = controller();
    await c.reload();
    c
      ..setBody('- [ ] ship')
      ..pickFile(_todo)
      ..pickHeader('Tasks');
    expect(await c.save(), isTrue);
    final sent = notes.captures.single;
    expect((sent.notePath, sent.header), ('work/todo.md', 'Tasks'));
    expect(c.notice, 'Saved to work/todo.md');
    expect(c.dirty, isFalse);
  });

  test('locked notes hide headers until unlocked (T1.6)', () async {
    final c = controller();
    await c.reload();
    c.pickFile(_secret);
    expect(c.locked(_secret), isTrue);
    expect(c.headersFor(''), isEmpty);
    unlocked.add(SecurityLevel.restricted);
    expect(c.headersFor('pass'), ['Passwords']);
  });

  test('hidden projects are not offered', () async {
    await settings.setHiddenProjects(['vault']);
    final c = controller();
    await c.reload();
    expect(c.files.map((f) => f.relPath), ['work/todo.md']);
  });

  test('agent needs a title; event needs a valid duration', () async {
    final c = controller()
      ..setMode(CaptureMode.agent)
      ..setBody('details');
    expect(c.canSave, isFalse);
    c
      ..setTitle('Fix bug')
      ..setPriority(Priority.urgent);
    expect(await c.save(), isTrue);
    expect(notes.tasks.single.priority, Priority.urgent);

    c
      ..setMode(CaptureMode.event)
      ..setTitle('Gym')
      ..setPresetDuration(null)
      ..setCustomDuration('soon');
    expect(c.durationError, isNotNull);
    expect(c.canSave, isFalse);
    c.setCustomDuration('1h30m');
    expect(c.canSave, isTrue);
  });

  test('event saves with next quarter, weekly source, alarm hook', () async {
    final c = controller()
      ..setMode(CaptureMode.event)
      ..setTitle('Gym')
      ..setWeekly(true)
      ..shiftDay(1);
    expect(await c.save(), isTrue);
    final e = events.added.single;
    expect(e.dateIso, '2026-11-03');
    expect(e.startMin, 9 * 60 + 15);
    expect(e.durationSecs, 45 * 60);
    expect(e.source, EventSource.weekly);
    expect(saved.single, e);
    // A saved event must not leak its choices into the next capture.
    expect(c.weekly, isFalse);
    expect(c.eventDate, DateTime(2026, 11, 2));
  });
}
