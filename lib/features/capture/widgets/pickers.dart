import 'package:flutter/material.dart';

import '../../../data/models.dart';
import 'suggestion_list.dart';

/// Bottom sheet listing [files]; returns the picked one.
Future<NoteFileDto?> pickNote(
  BuildContext context, {
  required List<NoteFileDto> files,
  required bool Function(NoteFileDto file) locked,
}) => showModalBottomSheet<NoteFileDto>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _Sheet(
    title: 'Save to note',
    empty: 'No notes yet',
    rows: [
      for (final f in files)
        FileTile(
          file: f,
          locked: locked(f),
          onTap: () => Navigator.pop(context, f),
        ),
    ],
  ),
);

/// Bottom sheet listing [headers]; returns the picked one.
Future<String?> pickSection(
  BuildContext context, {
  required List<String> headers,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => _Sheet(
    title: 'Add under section',
    empty: 'This note has no sections',
    rows: [
      for (final h in headers)
        SectionTile(header: h, onTap: () => Navigator.pop(context, h)),
    ],
  ),
);

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.empty, required this.rows});

  final String title;
  final String empty;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (rows.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text(empty)),
          Flexible(child: ListView(shrinkWrap: true, children: rows)),
        ],
      ),
    );
  }
}
