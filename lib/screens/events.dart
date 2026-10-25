import 'package:flutter/material.dart';

import '../app_state.dart';
import '../backend.dart';
import '../notifications.dart';
import '../theme.dart';

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
    reload();
  }

  Future<void> reload() async {
    await Future.wait([_loadMonth(), _loadRepeat()]);
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Календарь')),
              ButtonSegment(value: false, label: Text('Список')),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _createDialog,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _repeatableBar(),
            const SizedBox(height: 12),
            if (_calendarView) _monthHeader() else const SizedBox.shrink(),
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
    const names = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() => _month = DateTime(_month.year, _month.month - 1));
              _loadMonth();
            },
          ),
          Text(
            '${names[_month.month]} ${_month.year}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() => _month = DateTime(_month.year, _month.month + 1));
              _loadMonth();
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
            title: const Text('▸ Repeatable (регулярные по дням недели)'),
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
                          _loadRepeat();
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
                onPressed: () => _repeatDialog(),
                icon: const Icon(Icons.add),
                label: Text('+ Добавить в ${_repeatDay.substring(0, 3)}'),
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
      _loadRepeat();
      _loadMonth();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
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
      _loadRepeat();
      _loadMonth();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
    }
  }

  Future<void> _createDialog() async {
    await showDialog(
      context: context,
      builder: (_) => _EventForm(state: widget.state),
    );
    _loadMonth();
  }

  Future<void> _settingsSheet() async {
    final s = widget.state;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: const Text('Уведомления о задачах'),
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
                title: const Text('Предупреждать за'),
                trailing: DropdownButton<int>(
                  value: s.notifMinutes,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('В момент начала')),
                    DropdownMenuItem(value: 5, child: Text('5 мин')),
                    DropdownMenuItem(value: 15, child: Text('15 мин')),
                    DropdownMenuItem(value: 30, child: Text('30 мин')),
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
                title: const Text('Системный будильник автоматически'),
                value: s.autoAlarm,
                onChanged: (v) async {
                  await s.setAutoAlarm(v);
                  setSheet(() {});
                },
              ),
              ListTile(
                title: const Text('Будильник по'),
                trailing: DropdownButton<String>(
                  value: s.alarmMode,
                  items: const [
                    DropdownMenuItem(
                      value: 'first',
                      child: Text('Первому событию дня'),
                    ),
                    DropdownMenuItem(value: 'tag', child: Text('Тегу #alarm')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    await s.setAlarmMode(v);
                    setSheet(() {});
                  },
                ),
              ),
              ListTile(
                title: const Text('За минут до события'),
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
                    Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          _cell(row * 7 + col, cellW, cellH, scheme),
                      ],
                    ),
                ],
              ),
              // Thin 1px dividers.
              for (var col = 1; col < 7; col++)
                Positioned(
                  left: col * cellW,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 1, color: scheme.outlineVariant),
                ),
              for (var row = 1; row < 6; row++)
                Positioned(
                  top: row * cellH,
                  left: 0,
                  right: 0,
                  child: Container(height: 1, color: scheme.outlineVariant),
                ),
              if (_selected != null)
                _popover(gridW, gridH, cellW, cellH, scheme),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(int index, double w, double h, ColorScheme scheme) {
    final cell = widget.cells[index];
    final selected = _selected == index;
    final today = Backend.isoOf(DateTime.now()) == cell.dateIso;
    final marker = cell.dayTitle ?? cell.repeatTitle ?? '';
    final markerColor = cell.dayTitle != null
        ? scheme.primary
        : cell.repeatTitle != null
        ? scheme.secondary
        : scheme.onSurface;
    return GestureDetector(
      onTap: () => _select(index),
      child: Container(
        width: w,
        height: h,
        color: selected ? scheme.primaryContainer : Colors.transparent,
        padding: const EdgeInsets.all(2),
        child: Opacity(
          opacity: cell.inCurrentMonth ? 1 : 0.35,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (marker.isNotEmpty)
                Text(
                  marker,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, color: markerColor),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: today
                    ? BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      )
                    : null,
                child: Text(
                  '${cell.dayNum}',
                  style: TextStyle(
                    fontWeight: today ? FontWeight.bold : FontWeight.normal,
                    color: today ? scheme.onPrimary : null,
                  ),
                ),
              ),
            ],
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
    _load();
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
                    onPressed: _day == null ? null : () => _add(),
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
                    if (event.isRepeatable) const Text('⟳ '),
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
            _load();
            widget.onChanged();
          }
        },
      ),
    );
  }

  Future<void> _add() async {
    await showDialog(
      context: context,
      builder: (_) =>
          _EventForm(state: widget.state, fixedDate: widget.dateIso),
    );
    _load();
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
  final Map<String, DayEventsDto> _days = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final isos = [
      for (var off = -7; off <= 30; off++)
        Backend.isoOf(now.add(Duration(days: off))),
    ];
    final results = await Future.wait(
      isos.map((iso) async {
        try {
          final day = await getDayEvents(rootDir: Backend.root, dateIso: iso);
          return MapEntry(iso, day);
        } catch (_) {
          return null;
        }
      }),
    );
    if (mounted) {
      setState(() {
        _days.clear();
        for (final entry in results) {
          if (entry != null && entry.value.events.isNotEmpty) {
            _days[entry.key] = entry.value;
          }
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_days.isEmpty) return const Center(child: Text('(no events)'));
    final isos = _days.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final iso in isos) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text('# $iso', style: mono(context, size: 13)),
          ),
          for (final event in _days[iso]!.events)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Row(
                  children: [
                    if (event.isRepeatable) const Text('⟳ '),
                    Expanded(child: Text(event.title)),
                  ],
                ),
                subtitle: Text(
                  '${event.timeHhmm} · ${event.durationStr}',
                  style: mono(context, size: 11),
                ),
              ),
            ),
        ],
      ],
    );
  }
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
          dateIso: _iso,
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
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
        dateIso: _iso,
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
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
                onPressed: widget.fixedDate != null && !widget.repeatable
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
                  labelText: 'Длит',
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
              TextButton(onPressed: _delete, child: const Text('Удалить')),
            if (widget.onDone != null)
              TextButton(
                onPressed: () => widget.onDone!(false),
                child: const Text('Назад'),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
            FilledButton(onPressed: _save, child: const Text('Сохранить')),
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
