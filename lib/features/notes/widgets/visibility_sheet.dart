import 'package:flutter/material.dart';

import '../../../data/settings_store.dart';

/// "Visible projects" sheet. Hidden projects leave the Notes list and
/// Capture suggestions.
Future<void> showVisibilitySheet(
  BuildContext context,
  SettingsStore settings,
  List<String> projects,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.5,
    builder: (context, scroll) => ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final hidden = settings.hiddenProjects.toSet();
        return ListView.builder(
          controller: scroll,
          itemCount: projects.length + 1,
          itemBuilder: (context, i) => i == 0
              ? const ListTile(
                  title: Text('Visible projects'),
                  subtitle: Text('Hidden projects stay out of Capture too.'),
                )
              : SwitchListTile(
                  title: Text(projects[i - 1]),
                  value: !hidden.contains(projects[i - 1]),
                  onChanged: (show) => settings.setHiddenProjects(
                    show
                        ? (hidden..remove(projects[i - 1])).toList()
                        : (hidden..add(projects[i - 1])).toList(),
                  ),
                ),
        );
      },
    ),
  ),
);
