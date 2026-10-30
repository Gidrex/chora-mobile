import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app_state.dart';
import '../../data/models.dart';
import '../../platform/notifications.dart';
import 'events_controller.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/event_form.dart';
import 'widgets/event_list.dart';
import 'widgets/repeatable_panel.dart';
import 'widgets/weekday_header.dart';

/// Calendar / list views over the month grid, repeatables and day sheets.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<EventsScreen> createState() => EventsScreenState();
}

class EventsScreenState extends State<EventsScreen> {
  bool _calendarView = true;
  EventsController? _controller;

  EventsController get _c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final controller = EventsController(
        AppScope.eventsOf(context),
        widget.state,
      )..addListener(_refresh);
      _controller = controller;
      unawaited(controller.reload());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
    final notice = _controller?.notice;
    if (notice != null) {
      _controller!.consumeNotice();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notice)));
    }
  }

  /// Refresh month grid and repeatables (called when the page is visible).
  Future<void> reload() => _controller?.reload() ?? Future.value();

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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
            RepeatablePanel(
              controller: controller,
              onEdit: (existing, index) =>
                  _repeatDialog(existing: existing, index: index),
              onDelete: controller.deleteRepeatable,
              onAdd: _repeatDialog,
            ),
            const SizedBox(height: 12),
            if (_calendarView) _monthHeader() else const SizedBox.shrink(),
            if (_calendarView) const WeekdayHeader(),
            if (_calendarView)
              CalendarGrid(
                cells: controller.cells,
                square: widget.state.fixedCells,
                controller: controller,
              )
            else
              EventList(controller: controller),
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
            onPressed: () => _c.pageMonth(-1),
          ),
          Text(
            MaterialLocalizations.of(context).formatMonthYear(_c.month),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _c.pageMonth(1),
          ),
        ],
      ),
    );
  }

  Future<void> _repeatDialog({EventDto? existing, int? index}) async {
    final result = await showDialog<EventDto>(
      context: context,
      builder: (_) =>
          EventForm(controller: _c, initial: existing, repeatable: true),
    );
    if (result == null || !mounted) return;
    await _c.upsertRepeatable(existing: existing, index: index, dto: result);
  }

  Future<void> _createDialog() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => EventForm(controller: _c),
    );
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
