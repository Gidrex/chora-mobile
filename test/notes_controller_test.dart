import 'package:chora_mobile/app_state.dart';
import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/data/notes_repository.dart';
import 'package:chora_mobile/features/notes/notes_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNotesRepository implements NotesRepository {
  FakeNotesRepository(this.files);

  final Map<String, String> files;
  final _revision = ValueNotifier<int>(0);
  int projectCalls = 0;

  @override
  ValueListenable<int> get revision => _revision;

  @override
  Future<void> invalidate() async {
    _revision.value++;
  }

  @override
  Future<List<ProjectDto>> projects() async {
    projectCalls++;
    return [
      ProjectDto(
        dir: 'work',
        about: 'Work notes',
        security: SecurityLevel.open,
        files: [
          for (final e in files.entries)
            NoteFileDto(
              relPath: e.key,
              fileName: e.key.split('/').last,
              security: SecurityLevel.open,
              about: '',
              headers: const [],
            ),
        ],
      ),
    ];
  }

  @override
  Future<NoteContentDto> readNote(String relPath) async {
    final text = files[relPath];
    if (text == null) throw const NotesFailure('not found');
    return NoteContentDto(text: text, security: SecurityLevel.open, about: '');
  }

  @override
  Future<void> saveNote(String relPath, String body) async {
    files[relPath] = body;
    _revision.value++;
  }

  @override
  Future<String> toggleCheckbox(String relPath, int lineIndex) async {
    final updated = '${files[relPath] ?? ''}\n[toggled $lineIndex]';
    files[relPath] = updated;
    _revision.value++;
    return updated;
  }
}

void main() {
  test('reload fills projects and filter narrows them', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    final controller = NotesController(
      FakeNotesRepository({'work/a.md': '# A'}),
      state,
    );
    await controller.reload();
    expect(controller.loading, isFalse);
    expect(controller.error, isNull);
    expect(controller.visibleProjects.map((p) => p.dir), ['work']);
    controller.setFilter('zzz');
    expect(controller.visibleProjects, isEmpty);
    controller.setFilter('wor');
    expect(controller.visibleProjects.map((p) => p.dir), ['work']);
    controller.dispose();
  });

  test('open/save/toggle round-trip through the repository', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    final repo = FakeNotesRepository({'work/a.md': '# A'});
    final controller = NotesController(repo, state);
    const file = NoteFileDto(
      relPath: 'work/a.md',
      fileName: 'a.md',
      security: SecurityLevel.open,
      about: '',
      headers: [],
    );
    await controller.open(file);
    expect(controller.fileText, '# A');
    expect(await controller.saveFile('# B'), isTrue);
    expect(controller.notice, 'Saved');
    expect(repo.files['work/a.md'], '# B');
    controller.consumeNotice();
    expect(controller.notice, isNull);
    await controller.toggleLine(0);
    expect(controller.fileText, contains('[toggled 0]'));
    controller.dispose();
  });

  test('repository revision refreshes the controller', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    final repo = FakeNotesRepository({'work/a.md': '# A'});
    final controller = NotesController(repo, state);
    await controller.reload();
    expect(repo.projectCalls, greaterThan(0));
    final before = repo.projectCalls;
    await repo.saveNote('work/a.md', '# changed');
    await Future<void>.delayed(Duration.zero);
    expect(repo.projectCalls, greaterThan(before));
    controller.dispose();
  });

  test('load failure surfaces as error', () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(await SharedPreferences.getInstance());
    final controller = NotesController(FakeNotesRepository({}), state);
    await controller.open(
      const NoteFileDto(
        relPath: 'missing.md',
        fileName: 'missing.md',
        security: SecurityLevel.open,
        about: '',
        headers: [],
      ),
    );
    expect(controller.fileError, 'not found');
    controller.dispose();
  });
}
