import 'package:flutter/material.dart';

import '../../../app_state.dart';
import '../../../ui/theme_helpers.dart';

/// "Visible projects" sheet. Hidden projects stay out of the list and out
/// of Capture `@`-autocomplete. The screen rebuilds via [AppState] itself.
Future<void> showVisibilitySheet(
  BuildContext context,
  AppState state,
  List<String> dirs,
) {
  final hidden = state.hiddenProjects.toSet();
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Visible projects',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            for (final dir in dirs)
              SwitchListTile(
                title: Text(dir, style: mono(ctx)),
                value: !hidden.contains(dir),
                onChanged: (v) async {
                  hidden.remove(dir);
                  if (!v) hidden.add(dir);
                  await state.setHiddenProjects(hidden.toList());
                  setSheet(() {});
                },
              ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Hidden projects are excluded from Capture @-autocomplete too.',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
