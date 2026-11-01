import 'package:flutter/material.dart';

/// The Capture app bar's primary action, with progress while saving.
class SaveButton extends StatelessWidget {
  const SaveButton({super.key, required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check),
      label: const Text('Save'),
    );
  }
}
