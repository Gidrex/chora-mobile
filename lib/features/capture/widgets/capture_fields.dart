import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../ui/theme_helpers.dart';
import '../capture_controller.dart';
import 'quick_bar.dart';
import 'suggestion_list.dart';
import 'target_chip.dart';

/// Title field, target chip, suggestions, body field and quick bar.
class CaptureFields extends StatelessWidget {
  const CaptureFields({
    super.key,
    required this.controller,
    required this.title,
    required this.body,
    required this.focusNode,
    required this.token,
    required this.onSubmitted,
    required this.onPickHeader,
    required this.onPickFile,
    required this.onCheckbox,
    required this.onProject,
    required this.onSection,
  });

  final CaptureController controller;
  final TextEditingController title;
  final TextEditingController body;
  final FocusNode focusNode;
  final String? token;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onPickHeader;
  final Future<void> Function(NoteFileDto file, String hit) onPickFile;
  final VoidCallback onCheckbox;
  final VoidCallback onProject;
  final VoidCallback onSection;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            hintText: 'Write your thoughts...',
            border: InputBorder.none,
            filled: false,
          ),
          textInputAction: TextInputAction.next,
          onSubmitted: onSubmitted,
        ),
        const SizedBox(height: 8),
        if (controller.targetNote != null)
          TargetChip(
            note: controller.targetNote!,
            header: controller.targetHeader,
            onClear: controller.clearTarget,
          ),
        if (token != null)
          token!.startsWith('#')
              ? HeaderSuggestions(
                  headers: controller.headersFor(token!),
                  onPick: onPickHeader,
                )
              : FileSuggestions(
                  files: controller.fileSuggestions(token!),
                  onPick: onPickFile,
                ),
        TextField(
          controller: body,
          focusNode: focusNode,
          maxLines: 8,
          minLines: 4,
          style: mono(context, size: 13.5),
          decoration: const InputDecoration(
            hintText: 'Markdown, - [ ] checklists, @project, #section',
          ),
        ),
        const SizedBox(height: 8),
        QuickBar(
          onCheckbox: onCheckbox,
          onProject: onProject,
          onSection: onSection,
        ),
      ],
    );
  }
}
