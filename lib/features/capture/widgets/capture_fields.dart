import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../ui/theme_helpers.dart';
import '../capture_controller.dart';
import 'suggestion_list.dart';

/// Title field, markdown body with `@`/`#` suggestions, checklist button.
class CaptureFields extends StatelessWidget {
  const CaptureFields({
    super.key,
    required this.controller,
    required this.title,
    required this.body,
    required this.bodyFocus,
    required this.token,
    required this.onPickFile,
    required this.onPickHeader,
    required this.onCheckbox,
  });

  final CaptureController controller;
  final TextEditingController title;
  final TextEditingController body;
  final FocusNode bodyFocus;

  /// Active `@`/`#` token before the cursor, null when no suggestions show.
  final String? token;
  final ValueChanged<NoteFileDto> onPickFile;
  final ValueChanged<String> onPickHeader;
  final VoidCallback onCheckbox;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: title,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Title'),
          onSubmitted: (_) => bodyFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: body,
          focusNode: bodyFocus,
          minLines: 4,
          maxLines: 10,
          style: mono(context, size: 14),
          decoration: InputDecoration(
            labelText: 'Text',
            alignLabelWithHint: true,
            hintText: controller.mode == CaptureMode.event
                ? 'Details'
                : 'Markdown. Type @ for a note, # for a section',
            suffixIcon: IconButton(
              icon: const Icon(Icons.check_box_outlined),
              tooltip: 'Add checklist item',
              onPressed: onCheckbox,
            ),
          ),
        ),
        if (token != null) _suggestions(token!),
      ],
    );
  }

  Widget _suggestions(String token) {
    final query = token.substring(1);
    if (token.startsWith('#')) {
      return HeaderSuggestions(
        headers: controller.headersFor(query),
        onPick: onPickHeader,
      );
    }
    return FileSuggestions(
      files: controller.filesFor(query),
      locked: controller.locked,
      onPick: onPickFile,
    );
  }
}
