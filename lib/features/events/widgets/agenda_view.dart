import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../domain/dates.dart';
import '../../../domain/events_view.dart';
import 'event_tile.dart';
import '../../../ui/tones.dart';

/// The next [agendaDays] days, grouped under day headers.
class AgendaView extends StatelessWidget {
  const AgendaView({
    super.key,
    required this.events,
    required this.today,
    required this.loading,
    required this.onAdd,
    required this.onEdit,
  });

  final List<EventDto> events;
  final DateTime today;
  final bool loading;
  final VoidCallback onAdd;
  final ValueChanged<EventDto> onEdit;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      // Scrollable so pull-to-refresh still works on the empty state.
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!loading) ...[
            Text(
              'Nothing in the next $agendaDays days.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('New event'),
              ),
            ),
          ],
        ],
      );
    }
    final rows = <Object>[
      for (final group in groupByDay(events)) ...[group.day, ...group.events],
    ];
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        96 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: rows.length,
      itemBuilder: (_, i) => switch (rows[i]) {
        final EventDto e => EventTile(event: e, onTap: () => onEdit(e)),
        final DateTime day => _DayLabel(day: day, today: today),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.day, required this.today});

  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final label = MaterialLocalizations.of(context).formatMediumDate(day);
    final relative = sameDay(day, today)
        ? 'Today · '
        : sameDay(day, addDays(today, 1))
        ? 'Tomorrow · '
        : '';
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          '$relative$label',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Tones.of(context).heading),
        ),
      ),
    );
  }
}
