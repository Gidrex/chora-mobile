import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../ui/theme_helpers.dart';

/// One project card with its file rows (tree indent preserved).
class ProjectTile extends StatelessWidget {
  const ProjectTile({
    super.key,
    required this.project,
    required this.expanded,
    required this.onToggle,
    required this.onOpenFile,
  });

  final ProjectDto project;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<NoteFileDto> onOpenFile;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(
              project.dir,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: project.about.isEmpty ? null : Text(project.about),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                securityBadge(context, project.security.name),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            onTap: onToggle,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
              child: Column(
                children: [
                  for (final f in project.files) _fileRow(context, f),
                  if (project.files.isEmpty)
                    const ListTile(dense: true, title: Text('(empty)')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _fileRow(BuildContext context, NoteFileDto f) {
    final scheme = Theme.of(context).colorScheme;
    final depth = f.relPath.split('/').length - 1;
    final label = f.relPath.startsWith('${project.dir}/')
        ? f.relPath.substring(project.dir.length + 1)
        : f.fileName;
    return InkWell(
      onTap: () => onOpenFile(f),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: depth * 14,
              child: depth == 0
                  ? null
                  : Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
            ),
            Container(width: 10, height: 1, color: scheme.outlineVariant),
            const SizedBox(width: 4),
            Expanded(child: Text(label, style: mono(context))),
            securityBadge(context, f.security.name),
          ],
        ),
      ),
    );
  }
}
