import '../data/models.dart';

/// File name without the `.md` extension, for display.
String noteTitle(NoteFileDto file) => file.name.endsWith('.md')
    ? file.name.substring(0, file.name.length - 3)
    : file.name;

/// Folder of a note relative to the notes root, or "Loose notes".
String noteFolder(NoteFileDto file) {
  final slash = file.relPath.lastIndexOf('/');
  return slash < 0 ? 'Loose notes' : file.relPath.substring(0, slash);
}

/// Projects to show: [hidden] ones dropped (the loose group never is), and
/// with a [query] only files whose path, h1 or about contain it, case-insensitive.
/// Projects left without files are dropped while searching.
List<ProjectDto> filterProjects(
  List<ProjectDto> all, {
  required String query,
  required Set<String> hidden,
}) {
  final q = query.trim().toLowerCase();
  final out = <ProjectDto>[];
  for (final p in all) {
    if (!p.isLoose && hidden.contains(p.name)) continue;
    if (q.isEmpty) {
      out.add(p);
      continue;
    }
    final files = [
      for (final f in p.files)
        if (f.relPath.toLowerCase().contains(q) ||
            f.title.toLowerCase().contains(q) ||
            f.about.toLowerCase().contains(q))
          f,
    ];
    if (files.isEmpty) continue;
    out.add(
      ProjectDto(
        name: p.name,
        isLoose: p.isLoose,
        security: p.security,
        about: p.about,
        files: files,
      ),
    );
  }
  return out;
}
