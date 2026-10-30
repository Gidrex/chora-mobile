import 'package:flutter/material.dart';

import '../../../ui/theme_helpers.dart';

/// `@note#header` target chip with a clear button.
class TargetChip extends StatelessWidget {
  const TargetChip({
    super.key,
    required this.note,
    required this.header,
    required this.onClear,
  });

  final String note;
  final String? header;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        children: [
          Chip(
            label: Text(
              '@$note${header == null ? '' : '#$header'}',
              style: mono(context),
            ),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: onClear,
          ),
        ],
      ),
    );
  }
}
