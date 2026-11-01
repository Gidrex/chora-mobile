import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/domain/notes_filter.dart';
import 'package:chora_mobile/domain/notes_tree.dart';
import 'package:flutter_test/flutter_test.dart';

NoteFileDto file(String rel, {String title = ''}) => NoteFileDto(
  relPath: rel,
  name: rel.split('/').last,
  title: title,
  security: SecurityLevel.open,
  about: '',
  headers: const [],
);

final work = ProjectDto(
  name: 'work',
  isLoose: false,
  security: SecurityLevel.restricted,
  about: '',
  files: [
    file('work/todo.md'),
    file('work/guides/deploy.md', title: 'Deploy'),
    file('work/guides/ops/pager.md'),
    file('work/Archive.md'),
  ],
);

/// `depth:name` per row, folders as `name/`.
List<String> shape(List<TreeRow> rows) => [
  for (final r in rows)
    switch (r) {
      FolderRow(:final name) => '${r.depth}:$name/',
      NoteRow(:final file) => '${r.depth}:${file.name}',
    },
];

void main() {
  test('project starts open, subfolders closed, folders before notes', () {
    final rows = projectRows(work, toggled: {}, expandAll: false);
    expect(shape(rows), ['0:work/', '1:guides/', '1:Archive.md', '1:todo.md']);
    final project = rows.first as FolderRow;
    expect(project.count, 4);
    expect(project.security, SecurityLevel.restricted);
    expect((rows[1] as FolderRow).count, 2);
  });

  test('toggling opens nested folders and closes the project', () {
    final open = projectRows(
      work,
      toggled: {'work/guides', 'work/guides/ops'},
      expandAll: false,
    );
    expect(shape(open), [
      '0:work/',
      '1:guides/',
      '2:ops/',
      '3:pager.md',
      '2:deploy.md',
      '1:Archive.md',
      '1:todo.md',
    ]);
    expect(shape(projectRows(work, toggled: {'work'}, expandAll: false)), [
      '0:work/',
    ]);
  });

  test('search keeps ancestors of matches and opens them', () {
    final hit = filterProjects([work], query: 'pager', hidden: {}).single;
    final rows = projectRows(hit, toggled: {'work'}, expandAll: true);
    expect(shape(rows), ['0:work/', '1:guides/', '2:ops/', '3:pager.md']);
    final byTitle = filterProjects([work], query: 'deploy', hidden: {});
    expect(byTitle.single.files.single.title, 'Deploy');
  });

  test('loose notes get their own group', () {
    final loose = ProjectDto(
      name: '',
      isLoose: true,
      security: SecurityLevel.open,
      about: '',
      files: [file('inbox.md'), file('a.md')],
    );
    final rows = projectRows(loose, toggled: {}, expandAll: false);
    expect(shape(rows), ['0:Loose notes/', '1:a.md', '1:inbox.md']);
    expect((rows.first as FolderRow).path, looseKey);
  });
}
