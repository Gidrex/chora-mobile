import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../domain/notes_filter.dart';
import '../../../ui/tones.dart';

/// Autocomplete panel: rounded box under the body field, capped height.
class SuggestionPanel extends StatelessWidget {
  const SuggestionPanel({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView(shrinkWrap: true, children: rows),
        ),
      ),
    );
  }
}

/// Section completions for the picked note, as plain header titles.
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
        rows: [ListTile(title: Text('No matching sections'))],
      );
    }
    return SuggestionPanel(
      rows: [
        for (final h in headers.take(8))
          SectionTile(header: h, onTap: () => onPick(h)),
      ],
    );
  }
}

/// Note completions. Locked notes show a lock instead of their headers.
class FileSuggestions extends StatelessWidget {
  const FileSuggestions({
    super.key,
    required this.files,
    required this.locked,
    required this.onPick,
  });

  final List<NoteFileDto> files;
  final bool Function(NoteFileDto file) locked;
  final ValueChanged<NoteFileDto> onPick;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const SuggestionPanel(
        rows: [ListTile(title: Text('No matching notes'))],
      );
    }
    return SuggestionPanel(
      rows: [
        for (final f in files.take(8))
          FileTile(file: f, locked: locked(f), onTap: () => onPick(f)),
      ],
    );
  }
}

/// One note row: file icon (lock when gated), path, about.
class FileTile extends StatelessWidget {
  const FileTile({
    super.key,
    required this.file,
    required this.locked,
    required this.onTap,
  });

  final NoteFileDto file;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    return ListTile(
      leading: Icon(
        locked ? Icons.lock_outline : Icons.description_outlined,
        color: tones.file,
        semanticLabel: locked ? 'Locked' : null,
      ),
      title: Text(file.name, style: TextStyle(color: tones.file)),
      subtitle: Text(
        [
          noteFolder(file),
          if (!locked && file.title.isNotEmpty) file.title,
        ].join(' · '),
        style: TextStyle(color: tones.muted),
      ),
      onTap: onTap,
    );
  }
}

/// One section row: tag icon and title in the section tone.
class SectionTile extends StatelessWidget {
  const SectionTile({super.key, required this.header, required this.onTap});

  final String header;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = Tones.of(context).section;
    return ListTile(
      leading: Icon(Icons.tag, color: tone),
      title: Text(header, style: TextStyle(color: tone)),
      onTap: onTap,
    );
  }
}
