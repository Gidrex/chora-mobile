import 'package:flutter/material.dart';

/// Checkbox / @ / # shortcuts inserting snippets at the cursor.
class QuickBar extends StatelessWidget {
  const QuickBar({
    super.key,
    required this.onCheckbox,
    required this.onProject,
    required this.onSection,
  });

  final VoidCallback onCheckbox;
  final VoidCallback onProject;
  final VoidCallback onSection;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onCheckbox,
            icon: const Icon(Icons.check_box_outlined, size: 18),
            label: const Text('Checkbox'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onProject,
            icon: const Text('@'),
            label: const Text('Project'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onSection,
            icon: const Text('#'),
            label: const Text('Section'),
          ),
        ],
      ),
    );
  }
}
