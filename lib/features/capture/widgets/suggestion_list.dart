import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../ui/theme_helpers.dart';

/// Autocomplete panel shell: elevated rounded box with capped height.
class SuggestionPanel extends StatelessWidget {
  const SuggestionPanel({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.primary),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView(shrinkWrap: true, children: rows),
        ),
      ),
    );
  }
}

/// `#`-header completions for the picked target file.
class HeaderSuggestions extends StatelessWidget {
  const HeaderSuggestions({
    super.key,
    required this.headers,
    required this.onPick,
  });

  final List<String> headers;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return const SuggestionPanel(
        rows: [ListTile(dense: true, title: Text('No matching headers'))],
      );
    }
    return SuggestionPanel(
      rows: [
        for (final h in headers.take(8))
          ListTile(
            dense: true,
            title: Text('# $h', style: mono(context)),
            onTap: () => onPick(h),
          ),
      ],
    );
  }
}

/// `@`-file completions. `hit` carries the joined `#header`, if any.
class FileSuggestions extends StatelessWidget {
  const FileSuggestions({super.key, required this.files, required this.onPick});

  final List<({NoteFileDto file, String hit})> files;
  final Future<void> Function(NoteFileDto file, String hit) onPick;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const SuggestionPanel(
        rows: [ListTile(dense: true, title: Text('No matching notes'))],
      );
    }
    return SuggestionPanel(
      rows: [
        for (final e in files.take(8))
          ListTile(
            dense: true,
            leading: const Icon(Icons.folder_outlined, size: 18),
            title: Text(e.file.relPath, style: mono(context)),
            trailing: Text(
              '[${e.file.security.name}]',
              style: mono(context, size: 11),
            ),
            onTap: () => onPick(e.file, e.hit),
          ),
      ],
    );
  }
}
