import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../domain/markdown_tasks.dart';
import '../../../ui/tones.dart';

/// Note preview: markdown chunks plus task rows that toggle on tap.
class NoteBlocks extends StatelessWidget {
  const NoteBlocks({super.key, required this.text, required this.onToggle});

  final String text;

  /// Toggle the task on raw line `line`.
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final blocks = noteBlocks(text);
    final sheet = _sheet(Theme.of(context), Tones.of(context));
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: blocks.length,
      itemBuilder: (_, i) => switch (blocks[i]) {
        MarkdownChunk(:final text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: MarkdownBody(data: text, selectable: true, styleSheet: sheet),
        ),
        final TaskRow row => _TaskTile(
          row: row,
          sheet: sheet,
          onTap: () => onToggle(row.line),
        ),
      },
    );
  }

  /// Headings step down clearly in size, weight and tone: # > ## > ###.
  static MarkdownStyleSheet _sheet(ThemeData theme, Tones tones) {
    final t = theme.textTheme;
    final base = MarkdownStyleSheet.fromTheme(theme);
    return base.copyWith(
      h1: t.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: tones.heading,
      ),
      h2: t.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: tones.file,
      ),
      h3: t.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: tones.folder,
      ),
      h4: t.titleSmall?.copyWith(color: tones.section),
      code: base.code?.copyWith(color: tones.time),
      blockquote: base.blockquote?.copyWith(color: tones.muted),
      h1Padding: const EdgeInsets.only(top: 16, bottom: 4),
      h2Padding: const EdgeInsets.only(top: 12, bottom: 4),
      h3Padding: const EdgeInsets.only(top: 8),
      p: t.bodyLarge,
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.row,
    required this.sheet,
    required this.onTap,
  });

  final TaskRow row;
  final MarkdownStyleSheet sheet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = row.checked
        ? sheet.p?.copyWith(
            color: scheme.onSurfaceVariant,
            decoration: TextDecoration.lineThrough,
          )
        : sheet.p;
    return Semantics(
      checked: row.checked,
      label: row.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.only(left: row.indent * 8.0),
            child: Row(
              children: [
                IgnorePointer(
                  child: Checkbox(value: row.checked, onChanged: (_) {}),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: MarkdownBody(
                    data: row.label,
                    styleSheet: sheet.copyWith(p: label),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
