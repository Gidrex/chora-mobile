import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../backend.dart';
import '../platform/notifications.dart';
import '../ui/theme_helpers.dart';
import 'weekday_header.dart';

const _weekdays = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// Calendar with anchored popover + chronological list + repeatables.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<EventsScreen> createState() => EventsScreenState();
}

class EventsScreenState extends State<EventsScreen> {
  bool _calendarView = true;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<CalendarCellDto> _cells = [];
  bool _repeatOpen = false;
  String _repeatDay = _weekdays[(DateTime.now().weekday - 1) % 7];
  List<EventDto> _repeatEvents = [];

  @override
  void initState() {
    super.initState();
    unawaited(reload());
  }

  Future<void> reload() async {
    await Future.wait([_loadMonth(), _loadRepeat()]);
  }

  void _fail(Object e) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
  }

  Future<void> _loadMonth() async {
    try {
      final cells = await getCalendarMonth(
        rootDir: Backend.root,
        year: _month.year,
        month: _month.month,
        showRepeat: widget.state.showRepeat,
      );
      if (mounted) setState(() => _cells = cells);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _loadRepeat() async {
    try {
      final events = await getRepeatableWeekday(
        rootDir: Backend.root,
        weekday: _repeatDay,
      );
      if (mounted) setState(() => _repeatEvents = events);
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Calendar')),
              ButtonSegment(value: false, label: Text('List')),
            ],
            selected: {_calendarView},
            onSelectionChanged: (s) => setState(() => _calendarView = s.first),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _settingsSheet,
          ),
        ],
      ),
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          onPressed: _createDialog,
          shape: const CircleBorder(),
          backgroundColor: scheme.inverseSurface,
          foregroundColor: scheme.onInverseSurface,
          elevation: 6,
          child: const Icon(Icons.add, size: 32),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _repeatableBar(),
            const SizedBox(height: 12),
            if (_calendarView) _monthHeader() else const SizedBox.shrink(),
            if (_calendarView) const WeekdayHeader(),
            if (_calendarView)
              CalendarGridWidget(
                cells: _cells,
                square: widget.state.fixedCells,
                onChanged: _loadMonth,
                state: widget.state,
              )
            else
              const _EventList(),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _month = DateTime(_month.year, _month.month - 1));
              unawaited(_loadMonth());
            },
          ),
          Text(
            MaterialLocalizations.of(context).formatMonthYear(_month),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _month = DateTime(_month.year, _month.month + 1));
              unawaited(_loadMonth());
            },
          ),
        ],
      ),
    );
  }

  Widget _repeatableBar() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: const Text('Repeatable'),
            trailing: Icon(_repeatOpen ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _repeatOpen = !_repeatOpen),
          ),
          if (_repeatOpen) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  for (final day in _weekdays)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(day.substring(0, 3)),
                        selected: _repeatDay == day,
                        onSelected: (_) {
                          setState(() => _repeatDay = day);
                          unawaited(_loadRepeat());
                        },
                      ),
                    ),
                ],
              ),
            ),
            for (var i = 0; i < _repeatEvents.length; i++)
              ListTile(
                dense: true,
                title: Text(_repeatEvents[i].title),
                subtitle: Text(
                  '${_repeatEvents[i].timeHhmm} · ${_repeatEvents[i].durationStr}',
                  style: mono(context),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () =>
                          _repeatDialog(existing: _repeatEvents[i], index: i),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () => _deleteRepeat(i),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: OutlinedButton.icon(
                onPressed: _repeatDialog,
                icon: const Icon(Icons.add),
                label: Text('+ Add to ${_repeatDay.substring(0, 3)}'),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (_repeatOpen)
            Container(height: 1, color: scheme.outlineVariant)
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Future<void> _deleteRepeat(int index) async {
    final next = [..._repeatEvents]..removeAt(index);
    final renumbered = [
      for (var i = 0; i < next.length; i++)
        EventDto(
          index: BigInt.from(i),
          title: next[i].title,
          dateIso: next[i].dateIso,
          timeHhmm: next[i].timeHhmm,
          durationStr: next[i].durationStr,
          context: next[i].context,
          isRepeatable: true,
        ),
    ];
    try {
      await saveRepeatableWeekday(
        rootDir: Backend.root,
        weekday: _repeatDay,
        events: renumbered,
      );
      await Future.wait([_loadRepeat(), _loadMonth()]);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _repeatDialog({EventDto? existing, int? index}) async {
    final result = await showDialog<EventDto>(
      context: context,
      builder: (_) =>
          _EventForm(initial: existing, repeatable: true, state: widget.state),
    );
    if (result == null) return;
    final next = [..._repeatEvents];
    if (existing != null && index != null) {
      next[index] = result;
    } else {
      next.add(result);
    }
    final renumbered = [
      for (var i = 0; i < next.length; i++)
        EventDto(
          index: BigInt.from(i),
          title: next[i].title,
          dateIso: next[i].dateIso,
          timeHhmm: next[i].timeHhmm,
          durationStr: next[i].durationStr,
          context: next[i].context,
          isRepeatable: true,
        ),
    ];
    try {
      await saveRepeatableWeekday(
        rootDir: Backend.root,
        weekday: _repeatDay,
        events: renumbered,
      );
      await Future.wait([_loadRepeat(), _loadMonth()]);
    } catch (e) {
      _fail(e);
    }
  }

  Future<void> _createDialog() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _EventForm(state: widget.state),
    );
    await _loadMonth();
  }

  Future<void> _settingsSheet() async {
    final s = widget.state;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('Task notifications'),
                value: s.notifEnabled,
                onChanged: (v) async {
                  await s.setNotifEnabled(v);
                  await Reminders.rescheduleUpcoming(
                    enabled: v,
                    minutesBefore: s.notifMinutes,
                  );
                  setSheet(() {});
                },
              ),
              ListTile(
                title: const Text('Notify before'),
                trailing: DropdownButton<int>(
                  value: s.notifMinutes,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('At start')),
                    DropdownMenuItem(value: 5, child: Text('5 min')),
                    DropdownMenuItem(value: 15, child: Text('15 min')),
                    DropdownMenuItem(value: 30, child: Text('30 min')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await s.setNotifMinutes(v);
                    await Reminders.rescheduleUpcoming(
                      enabled: s.notifEnabled,
                      minutesBefore: v,
                    );
                    setSheet(() {});
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Automatic system alarm'),
                value: s.autoAlarm,
                onChanged: (v) async {
                  await s.setAutoAlarm(v);
                  setSheet(() {});
                },
              ),
              ListTile(
                title: const Text('Alarm for'),
                trailing: DropdownButton<String>(
                  value: s.alarmMode,
                  items: const [
                    DropdownMenuItem(
                      value: 'first',
                      child: Text('First event of the day'),
                    ),
                    DropdownMenuItem(value: 'tag', child: Text('#alarm tag')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await s.setAlarmMode(v);
                    setSheet(() {});
                  },
                ),
              ),
              ListTile(
                title: const Text('Minutes before'),
                trailing: DropdownButton<int>(
                  value: s.alarmBeforeMin,
                  items: const [5, 10, 15, 30, 60]
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m')))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    await s.setAlarmBeforeMin(v);
                    setSheet(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 7x6 TUI-style grid; tapping a date opens an anchored popover bubble.
class CalendarGridWidget extends StatefulWidget {
  const CalendarGridWidget({
    super.key,
    required this.cells,
    required this.square,
    required this.onChanged,
    required this.state,
  });

  final List<CalendarCellDto> cells;
  final bool square;
  final VoidCallback onChanged;
  final AppState state;

  @override
  State<CalendarGridWidget> createState() => _CalendarGridWidgetState();
}

class _CalendarGridWidgetState extends State<CalendarGridWidget>
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
    final today = Backend.isoOf(DateTime.now()) == cell.dateIso;
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
          child: _DayPopover(
            width: popW,
            height: popH,
            state: widget.state,
            dateIso: widget.cells[index].dateIso,
            onClose: () => setState(() => _selected = null),
            onChanged: () {
              widget.onChanged();
              setState(() {});
            },
          ),
        ),
      ),
    );
  }
}

/// Bubble card with the day's events; tap an event to edit just it.
class _DayPopover extends StatefulWidget {
  const _DayPopover({
    required this.width,
    required this.height,
    required this.dateIso,
    required this.onClose,
    required this.onChanged,
    required this.state,
  });

  final double width;
  final double height;
  final String dateIso;
  final VoidCallback onClose;
  final VoidCallback onChanged;
  final AppState state;

  @override
  State<_DayPopover> createState() => _DayPopoverState();
}

class _DayPopoverState extends State<_DayPopover> {
  DayEventsDto? _day;
  EventDto? _editing;
  bool _raw = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final day = await getDayEvents(
        rootDir: Backend.root,
        dateIso: widget.dateIso,
      );
      if (mounted) setState(() => _day = day);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          border: Border.all(color: scheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
              child: Row(
                children: [
                  Text('# ${widget.dateIso}', style: mono(context, size: 13)),
                  const Spacer(),
                  TextButton(
                    onPressed: _day == null
                        ? null
                        : () => setState(() => _raw = !_raw),
                    child: Text(_raw ? 'Events' : 'Raw MD'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: 'Add',
                    onPressed: _day == null ? null : _add,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _day == null
                  ? const Center(child: CircularProgressIndicator())
                  : _editing != null
                  ? _editForm()
                  : _raw
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _day!.rawMarkdown,
                        style: mono(context, size: 11.5),
                      ),
                    )
                  : _eventList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventList() {
    if (_day!.events.isEmpty) {
      return const Center(child: Text('(no events)'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: ListView(
        key: const ValueKey('list'),
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: [
          for (final event in _day!.events)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Row(
                  children: [
                    if (event.isRepeatable) const Icon(Icons.repeat, size: 14),
                    Expanded(child: Text(event.title)),
                  ],
                ),
                subtitle: Text(
                  '${event.timeHhmm} · ${event.durationStr}${event.context.isEmpty ? '' : '\n${event.context}'}',
                  style: mono(context, size: 11),
                ),
                onTap: () {
                  if (event.isRepeatable) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Repeatable: edit in the Repeatable section',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _editing = event);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _editForm() {
    final event = _editing!;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      child: _EventForm(
        key: ValueKey(event),
        state: widget.state,
        initial: event,
        fixedDate: widget.dateIso,
        onDone: (saved) {
          setState(() {
            _editing = null;
          });
          if (saved) {
            unawaited(_load());
            widget.onChanged();
          }
        },
      ),
    );
  }

  Future<void> _add() async {
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          _EventForm(state: widget.state, fixedDate: widget.dateIso),
    );
    await _load();
    widget.onChanged();
  }
}

/// Chronological list of days with Luma-style event cards.
class _EventList extends StatefulWidget {
  const _EventList();

  @override
  State<_EventList> createState() => _EventListState();
}

class _EventListState extends State<_EventList> {
  late String _iso = Backend.isoOf(DateTime.now());
  late DateTime _weekStart = _sundayOf(DateTime.now());
  DayEventsDto? _day;
  bool _loading = true;

  static DateTime _sundayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday % 7));

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final day = await getDayEvents(rootDir: Backend.root, dateIso: _iso);
      if (mounted) setState(() => _day = day);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(DateTime date) {
    setState(() => _iso = Backend.isoOf(date));
    unawaited(_load());
  }

  void _shiftWeek(int days) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: days));
      _iso = Backend.isoOf(Backend.dateOf(_iso).add(Duration(days: days)));
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = Backend.dateOf(_iso);
    final week = [
      for (var i = 0; i < 7; i++) _weekStart.add(Duration(days: i)),
    ];
    final events = _day?.events ?? const <EventDto>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shiftWeek(-7),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final day in week) _weekCell(day, scheme, date),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shiftWeek(7),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            _dayFull[(date.weekday - 1) % 7].toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 3,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (events.isEmpty)
          const Center(child: Text('(no events)'))
        else
          Stack(
            children: [
              Positioned(
                left: 13,
                top: 8,
                bottom: 8,
                child: Container(width: 2, color: scheme.outlineVariant),
              ),
              Column(
                children: [
                  for (final event in events)
                    _block(event, scheme, date, _accentsOf(context)),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _weekCell(DateTime day, ColorScheme scheme, DateTime selected) {
    final isSelected = day == selected;
    return InkWell(
      onTap: () => _select(day),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: isSelected
            ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle)
            : null,
        child: Center(
          child: Text(
            _weekLetters[day.weekday % 7],
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              color: isSelected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _block(
    EventDto event,
    ColorScheme scheme,
    DateTime day,
    List<Color> accents,
  ) {
    final color = _capsuleFor(event.title, accents);
    final start = _parseHm(event.timeHhmm);
    final startDt = start == null
        ? null
        : DateTime(day.year, day.month, day.day, start.hour, start.minute);
    final past = startDt != null && startDt.isBefore(DateTime.now());
    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (event.isRepeatable) const Icon(Icons.repeat, size: 14),
                  ],
                ),
                if (event.context.isNotEmpty)
                  Text(
                    event.context,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                start == null ? event.timeHhmm : _format12(start),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _humanDuration(event.durationStr),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color, blurRadius: 8, spreadRadius: 1),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: past ? Opacity(opacity: 0.45, child: card) : card),
      ],
    );
  }
}

const _weekLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const _dayFull = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Deterministic accent per event title (stable across restarts).
Color _capsuleFor(String title, List<Color> accents) {
  var hash = 0;
  for (final unit in title.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return accents[hash % accents.length];
}

List<Color> _accentsOf(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Theme.of(context).extension<EventPalette>()?.accents ??
      [scheme.primary, scheme.secondary, scheme.tertiary, scheme.error];
}

TimeOfDay? _parseHm(String raw) {
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Minutes from strings like `45m`, `1h`, `1h30m`.
int? _parseMinutes(String raw) {
  final match = RegExp(
    r'^\s*(?:(\d+)\s*h)?\s*(?:(\d+)\s*m)?\s*$',
  ).firstMatch(raw);
  if (match == null) return null;
  final total =
      (int.tryParse(match.group(1) ?? '0') ?? 0) * 60 +
      (int.tryParse(match.group(2) ?? '0') ?? 0);
  return total == 0 ? null : total;
}

String _format12(TimeOfDay t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// `1 hour 30 minutes` from `1h30m` (falls back to the raw string).
String _humanDuration(String raw) {
  final mins = _parseMinutes(raw);
  if (mins == null) return raw;
  final parts = <String>[];
  final hours = mins ~/ 60;
  final minutes = mins % 60;
  if (hours > 0) parts.add('$hours hour${hours == 1 ? '' : 's'}');
  if (minutes > 0) parts.add('$minutes minute${minutes == 1 ? '' : 's'}');
  return parts.join(' ');
}

/// Create / edit form for one event (also used for repeatables).
class _EventForm extends StatefulWidget {
  const _EventForm({
    super.key,
    required this.state,
    this.initial,
    this.fixedDate,
    this.repeatable = false,
    this.onDone,
  });

  final AppState state;
  final EventDto? initial;
  final String? fixedDate;
  final bool repeatable;
  final ValueChanged<bool>? onDone;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late final TextEditingController _title;
  late final TextEditingController _context;
  late final TextEditingController _duration;
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _context = TextEditingController(text: initial?.context ?? '');
    _duration = TextEditingController(text: initial?.durationStr ?? '45m');
    _date = initial != null && initial.dateIso.isNotEmpty
        ? Backend.dateOf(initial.dateIso)
        : widget.fixedDate != null
        ? Backend.dateOf(widget.fixedDate!)
        : DateTime.now();
    final parts = (initial?.timeHhmm ?? '').split(':');
    _time = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    _title.dispose();
    _context.dispose();
    _duration.dispose();
    super.dispose();
  }

  String get _iso => Backend.isoOf(_date);
  String get _hm =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  /// TUI easter egg for past dates (`src/tui.rs:116`).
  bool get _inPast =>
      _iso.compareTo(Backend.isoOf(DateTime.now())) < 0 &&
      widget.initial == null;

  void _fail(Object e) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is empty')));
      return;
    }
    try {
      if (widget.repeatable) {
        Navigator.pop(context, _asDto());
        return;
      }
      final dto = _asDto();
      if (widget.initial == null) {
        await createEvent(rootDir: Backend.root, event: dto);
      } else {
        await updateSingleEvent(
          rootDir: Backend.root,
          originalDateIso: widget.initial!.dateIso,
          sectionIndex: widget.initial!.index,
          updated: dto,
        );
      }
      final app = widget.state;
      await Reminders.rescheduleUpcoming(
        enabled: app.notifEnabled,
        minutesBefore: app.notifMinutes,
      );
      await Reminders.maybeAutoAlarm(
        enabled: app.autoAlarm,
        mode: app.alarmMode,
        beforeMin: app.alarmBeforeMin,
        event: dto,
      );
      if (mounted) {
        if (widget.onDone != null) {
          widget.onDone!(true);
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _fail(e);
    }
  }

  EventDto _asDto() => EventDto(
    index: widget.initial?.index ?? BigInt.zero,
    title: _title.text.trim(),
    dateIso: _iso,
    timeHhmm: _hm,
    durationStr: _duration.text.trim().isEmpty ? '45m' : _duration.text.trim(),
    context: _context.text.trim(),
    isRepeatable: widget.repeatable,
  );

  Future<void> _delete() async {
    final initial = widget.initial;
    if (initial == null || initial.isRepeatable) return;
    try {
      await deleteSingleEvent(
        rootDir: Backend.root,
        dateIso: initial.dateIso,
        sectionIndex: initial.index,
      );
      if (mounted) {
        if (widget.onDone != null) {
          widget.onDone!(true);
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _fail(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_inPast) Text("<'(o.o)'>", style: mono(context, size: 20)),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    widget.fixedDate != null &&
                        !widget.repeatable &&
                        widget.initial == null
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                child: Text(
                  _iso,
                  style: mono(context, size: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null) setState(() => _time = picked);
              },
              child: Text(_hm, style: mono(context)),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _duration,
                style: mono(context),
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _context,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Context'),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.initial != null &&
                !widget.initial!.isRepeatable &&
                !widget.repeatable)
              TextButton(onPressed: _delete, child: const Text('Delete')),
            if (widget.onDone != null)
              TextButton(
                onPressed: () => widget.onDone!(false),
                child: const Text('Back'),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ],
    );
    if (widget.onDone != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: content,
      );
    }
    return AlertDialog(
      title: Text(widget.initial == null ? 'New event' : 'Edit event'),
      content: SingleChildScrollView(child: content),
    );
  }
}
