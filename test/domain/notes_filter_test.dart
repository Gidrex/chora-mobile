import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/domain/notes_filter.dart';
import 'package:flutter_test/flutter_test.dart';

NoteFileDto file(String rel, {String about = ''}) => NoteFileDto(
  relPath: rel,
  name: rel.split('/').last,
  title: '',
  security: SecurityLevel.open,
  about: about,
  headers: const [],
);

ProjectDto project(
  String name,
  List<NoteFileDto> files, {
  bool loose = false,
}) => ProjectDto(
  name: name,
  isLoose: loose,
  security: SecurityLevel.open,
  about: '',
  files: files,
);

void main() {
  final all = [
    project('work', [file('work/todo.md'), file('work/guides/deploy.md')]),
    project('home', [file('home/shopping.md', about: 'Weekly list')]),
    project('', [file('inbox.md')], loose: true),
  ];

  test('query keeps only matching files', () {
    final hit = filterProjects(all, query: 'TODO', hidden: {});
    expect(hit.single.files.map((f) => f.relPath), ['work/todo.md']);
    expect(
      filterProjects(all, query: 'weekly', hidden: {}).single.name,
      'home',
    );
    expect(filterProjects(all, query: 'nothing', hidden: {}), isEmpty);
  });

  test('hidden projects drop, loose group stays', () {
    final shown = filterProjects(all, query: '', hidden: {'work', ''});
    expect(shown.map((p) => p.isLoose ? '(loose)' : p.name), [
      'home',
      '(loose)',
    ]);
  });

  test('titles drop .md', () {
    expect(noteTitle(file('home/shopping.md')), 'shopping');
  });

  test('folder of a note', () {
    expect(noteFolder(file('work/guides/deploy.md')), 'work/guides');
    expect(noteFolder(file('inbox.md')), 'Loose notes');
  });
}
