import 'package:flutter/material.dart';

import '../../../domain/event_time.dart';
import '../../../data/models.dart';
import '../events_controller.dart';
import 'day_sheet.dart';

/// 7x6 grid; tapping a date opens an anchored popover bubble.
/// Selection and the pop animation are ephemeral; day data loads through
/// [controller] inside the sheet.
class CalendarGrid extends StatelessWidget {
  const CalendarGrid({
    super.key,
    required this.cells,
    required this.square,
    required this.controller,
  });

  final List<CalendarCellDto> cells;
  final bool square;
  final EventsController controller;

  @override
  Widget build(BuildContext context) {
    return _GridBody(cells: cells, square: square, controller: controller);
  }
}

class _GridBody extends StatefulWidget {
  const _GridBody({
    required this.cells,
    required this.square,
    required this.controller,
  });

  final List<CalendarCellDto> cells;
  final bool square;
  final EventsController controller;

  @override
  State<_GridBody> createState() => _GridBodyState();
}

class _GridBodyState extends State<_GridBody>
    with SingleTickerProviderStateMixin {
  int? _selected;
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _select(int index) {
    setState(() => _selected = _selected == index ? null : index);
    if (_selected != null) _pop.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cells.length != 42) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final gridW = constraints.maxWidth;
        final cellW = gridW / 7;
        final cellH = widget.square ? cellW : cellW * 0.72;
        final gridH = cellH * 6;
        return SizedBox(
          width: gridW,
          height: gridH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  for (var row = 0; row < 6; row++)
                    SizedBox(
                      height: cellH,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var col = 0; col < 7; col++)
                            Expanded(child: _cell(row * 7 + col, scheme)),
                        ],
                      ),
                    ),
                ],
              ),
              if (_selected != null)
                _popover(gridW, gridH, cellW, cellH, scheme),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(int index, ColorScheme scheme) {
    final cell = widget.cells[index];
    final selected = _selected == index;
    final today = todayIso() == cell.dateIso;
    return GestureDetector(
      onTap: () => _select(index),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(12),
            border: today && !selected
                ? Border.all(color: scheme.primary, width: 2)
                : null,
          ),
          child: Opacity(
            opacity: cell.inCurrentMonth ? 1 : 0.35,
            // Scale down on narrow cells / large text instead of clipping
            // the event dots (T1.3).
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${cell.dayNum}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: today || selected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: selected ? scheme.onPrimaryContainer : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (cell.dayTitle != null)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (cell.dayTitle != null && cell.repeatTitle != null)
                        const SizedBox(width: 3),
                      if (cell.repeatTitle != null)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: scheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _popover(
    double gridW,
    double gridH,
    double cellW,
    double cellH,
    ColorScheme scheme,
  ) {
    final index = _selected!;
    final row = index ~/ 7;
    final col = index % 7;
    const popW = 300.0;
    const popH = 340.0;
    final cellCx = col * cellW + cellW / 2;
    final left = (cellCx - popW / 2).clamp(
      4.0,
      (gridW - popW - 4).clamp(4.0, gridW),
    );
    final below = row < 2;
    final top = below
        ? (row + 1) * cellH + 6
        : (row * cellH - popH - 6).clamp(4.0, gridH);
    final curved = CurvedAnimation(parent: _pop, curve: Curves.easeOutBack);
    return Positioned(
      left: left,
      top: top,
      child: FadeTransition(
        opacity: _pop,
        child: ScaleTransition(
          scale: curved,
          child: DaySheet(
            width: popW,
            height: popH,
            dateIso: widget.cells[index].dateIso,
            controller: widget.controller,
            onClose: () => setState(() => _selected = null),
          ),
        ),
      ),
    );
  }
}
