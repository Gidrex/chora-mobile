import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../domain/dates.dart';
import '../../../ui/tones.dart';

/// Sunday-first narrow weekday labels, matching the grid order.
class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final labels = MaterialLocalizations.of(context).narrowWeekdays;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
        ],
      ),
    );
  }
}

/// 6x7 month grid. Cells scale their content down instead of overflowing.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    super.key,
    required this.cells,
    required this.today,
    required this.selected,
    required this.square,
    required this.onSelect,
  });

  final List<CalendarCellDto> cells;
  final DateTime today;
  final DateTime selected;
  final bool square;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final cellW = constraints.maxWidth / 7;
        final cellH = square ? cellW : (cellW * 0.8).clamp(48.0, 96.0);
        return Column(
          children: [
            for (var row = 0; row < cells.length ~/ 7; row++)
              SizedBox(
                height: cellH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final cell in cells.skip(row * 7).take(7))
                      Expanded(child: _cell(cell)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _cell(CalendarCellDto cell) {
    final date = dateOf(cell.dateIso);
    return DayCell(
      cell: cell,
      isToday: sameDay(date, today),
      isSelected: sameDay(date, selected),
      onTap: () => onSelect(date),
    );
  }
}

/// One grid day: number, today ring, selected fill, day/weekly dots.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.cell,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final CalendarCellDto cell;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasEvents = cell.dayTitle != null || cell.repeatTitle != null;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(dateOf(cell.dateIso));
    return Semantics(
      button: true,
      selected: isSelected,
      label: [
        date,
        if (isToday) 'today',
        if (hasEvents) 'has events',
      ].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        // Own Material: ink and fill stay inside the scroll clip.
        child: Material(
          color: isSelected ? scheme.primaryContainer : Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isToday
                ? BorderSide(color: scheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onTap,
            child: Opacity(
              opacity: cell.inMonth ? 1 : 0.4,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: _DayContent(
                  cell: cell,
                  emphasized: isToday || isSelected,
                  color: isSelected ? scheme.onPrimaryContainer : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayContent extends StatelessWidget {
  const _DayContent({
    required this.cell,
    required this.emphasized,
    required this.color,
  });

  final CalendarCellDto cell;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${cell.day}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Filled dot = day event, ring = weekly event: not color-only.
              _Dot(
                color: tones.time,
                filled: true,
                show: cell.dayTitle != null,
              ),
              const SizedBox(width: 4),
              _Dot(
                color: tones.weekly,
                filled: false,
                show: cell.repeatTitle != null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.filled, required this.show});

  final Color color;
  final bool filled;
  final bool show;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: show
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? color : null,
              border: filled ? null : Border.all(color: color, width: 1.5),
            )
          : null,
    );
  }
}
