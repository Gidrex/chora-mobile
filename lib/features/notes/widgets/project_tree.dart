import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../domain/notes_tree.dart';
import '../../../ui/glass.dart';
import 'tree_rows.dart';

/// One project as a card-styled sliver: rows are built lazily, so a
/// project with hundreds of notes scrolls as cheaply as a flat list.
class ProjectTree extends StatelessWidget {
  const ProjectTree({
    super.key,
    required this.rows,
    required this.isLocked,
    required this.onToggle,
    required this.onOpen,
  });

  final List<TreeRow> rows;
  final bool Function(SecurityLevel level) isLocked;
  final ValueChanged<String> onToggle;
  final ValueChanged<NoteFileDto> onOpen;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      sliver: DecoratedSliver(
        // Slivers cannot host a backdrop blur: same glass fill and edge, unblurred.
        decoration: glassDecoration(context),
        sliver: SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, i) => _row(rows[i]),
          ),
        ),
      ),
    );
  }

  Widget _row(TreeRow row) => switch (row) {
    final FolderRow f => FolderTile(
      key: ValueKey('folder:${f.path}'),
      row: f,
      locked: f.security != null && isLocked(f.security!),
      onTap: () => onToggle(f.path),
    ),
    final NoteRow n => NoteTile(
      key: ValueKey('note:${n.file.relPath}'),
      row: n,
      locked: isLocked(n.file.security),
      onTap: () => onOpen(n.file),
    ),
  };
}
