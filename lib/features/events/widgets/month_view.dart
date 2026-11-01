import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../events_controller.dart';
import 'event_tile.dart';
import 'month_grid.dart';
import '../../../ui/tones.dart';

/// Month grid plus the selected day's events below it.
class MonthView extends StatelessWidget {
  const MonthView({
    super.key,
    required this.controller,
    required this.squareCells,
    required this.onAdd,
    required this.onEdit,
  });

  final EventsController controller;
  final bool squareCells;
  final ValueChanged<DateTime> onAdd;
  final ValueChanged<EventDto> onEdit;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListView(
      // Clear the floating FAB and the glass nav bar below it.
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        96 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _MonthHeader(
          month: c.month,
          onPrev: () => c.pageMonth(-1),
          onNext: () => c.pageMonth(1),
        ),
        const WeekdayHeader(),
        const SizedBox(height: 4),
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 200) c.pageMonth(v < 0 ? 1 : -1);
          },
          child: c.cells.isEmpty
              ? const SizedBox(height: 288)
              : MonthGrid(
                  cells: c.cells,
                  today: c.today,
                  selected: c.selected,
                  square: squareCells,
                  onSelect: c.select,
                ),
        ),
        const SizedBox(height: 16),
        _DayHeader(day: c.selected, onAdd: () => onAdd(c.selected)),
        const SizedBox(height: 8),
        if (c.dayEvents.isEmpty && !c.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No events this day.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        for (final event in c.dayEvents)
          EventTile(event: event, onTap: () => onEdit(event)),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: onPrev,
        ),
        Expanded(
          child: Text(
            MaterialLocalizations.of(context).formatMonthYear(month),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Tones.of(context).heading),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.onAdd});

  final DateTime day;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Text(
          MaterialLocalizations.of(context).formatMediumDate(day),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Tones.of(context).heading),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add event'),
        ),
      ],
    );
  }
}
