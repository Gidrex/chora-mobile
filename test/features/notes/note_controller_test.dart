import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/data/notes_repository.dart';
import 'package:chora_mobile/features/notes/note_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNotes implements NotesRepository {
  FakeNotes(this.text);

  String text;
  AppFailure? failNext;

  AppFailure? _take() {
    final f = failNext;
    failNext = null;
    return f;
  }

  @override
  Future<NoteDto> note(String relPath) async => NoteDto(
    relPath: relPath,
    text: text,
    security: SecurityLevel.open,
    about: '',
  );

  @override
  Future<void> save(String relPath, String text, {required String base}) async {
    final fail = _take();
    if (fail != null) throw fail;
    if (base != this.text) throw const AppFailure(ErrorKind.changed, 'x');
    this.text = text;
  }

  @override
  Future<String> toggleTask(
    String relPath,
    int line, {
    required String base,
  }) async {
    final fail = _take();
    if (fail != null) throw fail;
    text = base.replaceFirst('[ ]', '[x]');
    return text;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeNotes repo;
  late NoteController note;

  setUp(() async {
    repo = FakeNotes('- [ ] a\n');
    note = NoteController(repo, ValueNotifier(0), 'a.md');
    await note.load();
  });

  test('toggle is optimistic and persists', () async {
    final pending = note.toggle(0);
    expect(note.text, '- [x] a\n');
    await pending;
    expect(repo.text, '- [x] a\n');
  });

  test('failed toggle reverts and reports', () async {
    repo.failNext = const AppFailure(ErrorKind.io, 'disk full');
    await note.toggle(0);
    expect(note.text, '- [ ] a\n');
    expect(note.notice, 'disk full');
  });

  test('save over a synced change keeps edits and reloads', () async {
    repo.text = 'synced\n';
    final ok = await note.save('mine\n', base: '- [ ] a\n');
    expect(ok, isFalse);
    expect(note.text, 'synced\n');
    expect(note.notice, contains('Changed on another device'));
    expect(await note.save('mine\n', base: note.text!), isTrue);
    expect(repo.text, 'mine\n');
  });
}
