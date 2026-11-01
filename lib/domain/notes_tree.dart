import '../data/models.dart';

/// One visible row of a project's tree.
sealed class TreeRow {
  const TreeRow(this.depth);

  /// 0 for the project itself, +1 per folder level.
  final int depth;
}

/// A project (depth 0) or a folder inside it.
final class FolderRow extends TreeRow {
  const FolderRow({
    required int depth,
    required this.path,
    required this.name,
    required this.count,
    required this.open,
    this.security,
  }) : super(depth);

  /// Stable key: project name (or [looseKey]) plus subfolders, `/`-joined.
  final String path;
  final String name;

  /// Notes anywhere below this folder.
  final int count;
  final bool open;

  /// Only set for the project row.
  final SecurityLevel? security;
}

/// One note.
final class NoteRow extends TreeRow {
  const NoteRow({required int depth, required this.file}) : super(depth);

  final NoteFileDto file;
}

/// Tree key of the loose-notes group (no real dir has this name).
const looseKey = '(loose)';

/// Rows of [project]: the project row, then (when open) folders before
/// notes, each sorted by name. Projects start open, subfolders closed;
/// a path in [toggled] flips that. [expandAll] (search) opens everything.
List<TreeRow> projectRows(
  ProjectDto project, {
  required Set<String> toggled,
  required bool expandAll,
}) {
  final root = _Dir();
  final prefix = project.isLoose ? '' : '${project.name}/';
  for (final f in project.files) {
    final rel = f.relPath.startsWith(prefix)
        ? f.relPath.substring(prefix.length)
        : f.relPath;
    final parts = rel.split('/');
    var dir = root;
    for (final part in parts.take(parts.length - 1)) {
      dir = dir.dirs.putIfAbsent(part, _Dir.new);
    }
    dir.files.add(f);
  }
  final out = <TreeRow>[];
  final key = project.isLoose ? looseKey : project.name;
  _emit(
    out,
    root,
    path: key,
    name: project.isLoose ? 'Loose notes' : project.name,
    depth: 0,
    security: project.security,
    open: (String p, int d) => expandAll || ((d == 0) != toggled.contains(p)),
  );
  return out;
}

void _emit(
  List<TreeRow> out,
  _Dir dir, {
  required String path,
  required String name,
  required int depth,
  required bool Function(String path, int depth) open,
  SecurityLevel? security,
}) {
  final isOpen = open(path, depth);
  out.add(
    FolderRow(
      depth: depth,
      path: path,
      name: name,
      count: dir.count,
      open: isOpen,
      security: security,
    ),
  );
  if (!isOpen) return;
  for (final sub in _sorted(dir.dirs.keys)) {
    _emit(
      out,
      dir.dirs[sub]!,
      path: '$path/$sub',
      name: sub,
      depth: depth + 1,
      open: open,
    );
  }
  final files = [...dir.files]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  out.addAll(files.map((f) => NoteRow(depth: depth + 1, file: f)));
}

List<String> _sorted(Iterable<String> names) =>
    names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

class _Dir {
  final dirs = <String, _Dir>{};
  final files = <NoteFileDto>[];

  int get count =>
      files.length + dirs.values.fold(0, (sum, d) => sum + d.count);
}
