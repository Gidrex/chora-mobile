import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../ui/tones.dart';

/// Where a note capture lands: note chip (default "Inbox") and, once a
/// note is picked, a section chip. Tapping a chip opens its picker.
class TargetRow extends StatelessWidget {
  const TargetRow({
    super.key,
    required this.target,
    required this.header,
    required this.emptyLabel,
    required this.showSection,
    required this.onPickNote,
    required this.onPickSection,
    required this.onClear,
  });

  final NoteFileDto? target;
  final String? header;
  final String emptyLabel;
  final bool showSection;
  final VoidCallback onPickNote;
  final VoidCallback onPickSection;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final note = target;
    final tones = Tones.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        InputChip(
          avatar: Icon(Icons.description_outlined, color: tones.file),
          label: Text(note?.relPath ?? emptyLabel),
          labelStyle: TextStyle(color: tones.file),
          tooltip: 'Choose note',
          onPressed: onPickNote,
          onDeleted: note == null ? null : onClear,
          deleteButtonTooltipMessage: 'Clear note',
        ),
        if (note != null && showSection)
          InputChip(
            avatar: Icon(Icons.tag, color: tones.section),
            label: Text(header ?? 'Section'),
            labelStyle: TextStyle(color: tones.section),
            tooltip: 'Choose section',
            onPressed: onPickSection,
          ),
      ],
    );
  }
}
