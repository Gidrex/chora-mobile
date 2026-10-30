import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../ui/theme_helpers.dart';
import '../events_controller.dart';

/// Collapsible repeatable-events bar with per-day chips, edit/delete
/// actions and an add button. Dialogs are opened by the callbacks so the
/// sheet context stays with the screen.
class RepeatablePanel extends StatefulWidget {
  const RepeatablePanel({
    super.key,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  final EventsController controller;
  final void Function(EventDto existing, int index) onEdit;
  final ValueChanged<int> onDelete;
  final VoidCallback onAdd;

  @override
  State<RepeatablePanel> createState() => _RepeatablePanelState();
}

class _RepeatablePanelState extends State<RepeatablePanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = widget.controller;
    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: const Text('Repeatable'),
            trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _open = !_open),
          ),
          if (_open) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (final day in weekdays)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(day.substring(0, 3)),
                        selected: controller.repeatDay == day,
                        onSelected: (_) => controller.setRepeatDay(day),
                      ),
                    ),
                ],
              ),
            ),
            for (var i = 0; i < controller.repeatEvents.length; i++)
              ListTile(
                dense: true,
                title: Text(controller.repeatEvents[i].title),
                subtitle: Text(
                  '${controller.repeatEvents[i].timeHhmm} · ${controller.repeatEvents[i].durationStr}',
                  style: mono(context),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () =>
                          widget.onEdit(controller.repeatEvents[i], i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () => widget.onDelete(i),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: OutlinedButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add),
                label: Text('+ Add to ${controller.repeatDay.substring(0, 3)}'),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (_open)
            Container(height: 1, color: scheme.outlineVariant)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
