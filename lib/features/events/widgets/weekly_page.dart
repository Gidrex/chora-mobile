import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../domain/events_view.dart';
import '../events_controller.dart';
import 'event_tile.dart';
import 'open_event_form.dart';
import '../../../ui/tones.dart';

String _label(Weekday d) =>
    '${d.name[0].toUpperCase()}${d.name.substring(1, 3)}';

/// Weekly events per weekday, edited through the same event form.
class WeeklyPage extends StatefulWidget {
  const WeeklyPage({super.key, required this.controller, required this.day});

  final EventsController controller;
  final Weekday day;

  @override
  State<WeeklyPage> createState() => _WeeklyPageState();
}

class _WeeklyPageState extends State<WeeklyPage> {
  late Weekday _day = widget.day;
  Future<List<EventDto>>? _events;
  ({Weekday day, int gen})? _loaded;

  /// Reload only when the weekday or the storage changed.
  Future<List<EventDto>> _eventsFor(Weekday day, int gen) {
    if (_loaded != (day: day, gen: gen)) {
      _loaded = (day: day, gen: gen);
      _events = widget.controller.weekly(day);
    }
    return _events!;
  }

  Future<void> _open({EventDto? original}) => openEventForm(
    context,
    widget.controller,
    date: nextWeekday(_day, widget.controller.today),
    original: original,
    weekly: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly events')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add),
        label: const Text('New weekly event'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in Weekday.values)
                  ChoiceChip(
                    label: Text(_label(d)),
                    selected: d == _day,
                    selectedColor: Tones.of(
                      context,
                    ).weekly.withValues(alpha: 0.25),
                    onSelected: (_) => setState(() => _day = d),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (_, _) => FutureBuilder(
                future: _eventsFor(_day, widget.controller.generation),
                builder: (_, snap) => _WeeklyList(
                  snapshot: snap,
                  onEdit: (e) => _open(original: e),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyList extends StatelessWidget {
  const _WeeklyList({required this.snapshot, required this.onEdit});

  final AsyncSnapshot<List<EventDto>> snapshot;
  final ValueChanged<EventDto> onEdit;

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return Center(child: Text('${snapshot.error}'));
    }
    final events = snapshot.data;
    if (events == null) return const Center(child: CircularProgressIndicator());
    if (events.isEmpty) {
      return const Center(child: Text('No weekly events on this day.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        for (final e in events) EventTile(event: e, onTap: () => onEdit(e)),
      ],
    );
  }
}
