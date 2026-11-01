import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../data/settings_store.dart';
import '../../domain/events_view.dart';
import 'events_controller.dart';
import 'widgets/agenda_view.dart';
import 'widgets/month_view.dart';
import 'widgets/open_event_form.dart';
import 'widgets/weekly_page.dart';

/// Events tab: month grid with the selected day, or a 14-day agenda.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late final EventsController _c;
  late final SettingsStore _settings;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _settings = services.settings;
    _c = EventsController(
      services.events,
      services.settings,
      services.session.revision,
      afterSave: services.reminders.afterSave,
      refresh: services.session.refreshIfChanged,
    );
    unawaited(_c.load());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _open({required DateTime date, EventDto? original}) =>
      openEventForm(context, _c, date: date, original: original);

  void _openWeekly() => unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeeklyPage(controller: _c, day: weekdayOf(_c.selected)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([_c, _settings]),
      builder: (_, _) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Events'),
          actions: [
            IconButton(
              icon: const Icon(Icons.repeat),
              tooltip: 'Weekly events',
              onPressed: _openWeekly,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: _ViewToggle(view: _c.view, onChanged: _c.setView),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          onPressed: () =>
              _open(date: _c.view == EventsView.month ? _c.selected : _c.today),
          icon: const Icon(Icons.add),
          label: const Text('New event'),
        ),
        body: Column(
          children: [
            if (_c.loading) const LinearProgressIndicator(),
            if (_c.error != null)
              _ErrorBanner(message: _c.error!, retry: _c.load),
            Expanded(
              child: RefreshIndicator(onRefresh: _c.refresh, child: _body()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() => switch (_c.view) {
    EventsView.month => MonthView(
      controller: _c,
      squareCells: _settings.squareCells,
      onAdd: (day) => _open(date: day),
      onEdit: (e) => _open(date: _c.selected, original: e),
    ),
    EventsView.agenda => AgendaView(
      events: _c.agenda,
      today: _c.today,
      loading: _c.loading,
      onAdd: () => _open(date: _c.today),
      onEdit: (e) => _open(date: _c.today, original: e),
    ),
  };
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});

  final EventsView view;
  final Future<void> Function(EventsView) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SegmentedButton<EventsView>(
        segments: const [
          ButtonSegment(
            value: EventsView.month,
            icon: Icon(Icons.calendar_view_month),
            label: Text('Month'),
          ),
          ButtonSegment(
            value: EventsView.agenda,
            icon: Icon(Icons.view_agenda_outlined),
            label: Text('Agenda'),
          ),
        ],
        selected: {view},
        onSelectionChanged: (s) => unawaited(onChanged(s.first)),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.retry});

  final String message;
  final Future<void> Function() retry;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => unawaited(retry()),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
