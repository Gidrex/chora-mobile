import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../domain/notes_tree.dart';
import '../../../ui/tones.dart';

/// Horizontal step per tree level.
const _indent = 20.0;

/// Leading space before the first guide line.
const _gutter = 16.0;

/// A project or folder: chevron, folder icon, name, note count.
class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.row,
    required this.locked,
    required this.onTap,
  });

  final FolderRow row;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final text = Theme.of(context).textTheme;
    final isProject = row.depth == 0;
    final loose = row.path == looseKey;
    return Semantics(
      expanded: row.open,
      child: _TreeTile(
        depth: row.depth,
        onTap: onTap,
        leading: [
          Icon(
            row.open ? Icons.expand_more : Icons.chevron_right,
            color: tones.muted,
          ),
          const SizedBox(width: 4),
          Icon(
            loose
                ? Icons.inbox_outlined
                : row.open
                ? Icons.folder_open_outlined
                : Icons.folder_outlined,
            color: tones.folder,
          ),
        ],
        title: Text(
          row.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (isProject ? text.titleMedium : text.bodyLarge)?.copyWith(
            color: tones.folder,
            fontWeight: isProject ? FontWeight.w600 : null,
          ),
        ),
        trailing: [
          if (locked && row.security != null) LockLabel(level: row.security!),
          const SizedBox(width: 8),
          Text(
            '${row.count}',
            style: text.labelLarge?.copyWith(color: tones.duration),
          ),
        ],
      ),
    );
  }
}

/// A note: file name, then its h1 (hidden while the note is locked).
class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.row,
    required this.locked,
    required this.onTap,
  });

  final NoteRow row;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final text = Theme.of(context).textTheme;
    final title = row.file.title;
    return _TreeTile(
      depth: row.depth,
      onTap: onTap,
      leading: [
        const SizedBox(width: 28),
        Icon(
          locked ? Icons.lock_outline : Icons.description_outlined,
          color: locked ? tones.muted : tones.file,
        ),
      ],
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyLarge?.copyWith(color: tones.file),
          ),
          if (!locked && title.isNotEmpty)
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: tones.heading),
            ),
        ],
      ),
      trailing: [if (locked) LockLabel(level: row.file.security)],
    );
  }
}

/// Shared row: indent guides, leading icons, title, trailing, 48 dp min.
class _TreeTile extends StatelessWidget {
  const _TreeTile({
    required this.depth,
    required this.onTap,
    required this.leading,
    required this.title,
    required this.trailing,
  });

  final int depth;
  final VoidCallback onTap;
  final List<Widget> leading;
  final Widget title;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    // Own transparent Material: ink shows above the card decoration.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _Guides(
            depth: depth,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: EdgeInsets.fromLTRB(_gutter + depth * _indent, 6, 16, 6),
              child: Row(
                children: [
                  ...leading,
                  const SizedBox(width: 12),
                  Expanded(child: title),
                  ...trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One faint vertical line per ancestor level.
class _Guides extends CustomPainter {
  _Guides({required this.depth, required this.color});

  final int depth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var level = 1; level <= depth; level++) {
      final x = _gutter + (level - 1) * _indent + 12;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_Guides old) => old.depth != depth || old.color != color;
}

/// Lock icon plus level, shown only for content that needs an unlock.
class LockLabel extends StatelessWidget {
  const LockLabel({super.key, required this.level});

  final SecurityLevel level;

  @override
  Widget build(BuildContext context) {
    final color = level == SecurityLevel.critical
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.tertiary;
    final name = switch (level) {
      SecurityLevel.open => 'Locked',
      SecurityLevel.restricted => 'Restricted',
      SecurityLevel.critical => 'Critical',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          name,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
