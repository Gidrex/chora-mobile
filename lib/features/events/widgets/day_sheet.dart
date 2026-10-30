import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../data/notes_repository.dart';
import '../../../ui/theme_helpers.dart';
import '../events_controller.dart';
import 'event_form.dart';

/// Day details: raw markdown / event list with inline edit.
/// Self-sufficient: loads through [controller], refreshes after its writes.
class DaySheet extends StatefulWidget {
  const DaySheet({
    super.key,
    required this.width,
    required this.height,
    required this.dateIso,
    required this.controller,
    required this.onClose,
  });

  final double width;
  final double height;
  final String dateIso;
  final EventsController controller;
  final VoidCallback onClose;

  @override
  State<DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<DaySheet> {
  DayEventsDto? _day;
  EventDto? _editing;
  bool _raw = false;

  EventsController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final day = await _c.loadDay(widget.dateIso);
      if (mounted) setState(() => _day = day);
    } on NotesFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
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
      child: EventForm(
        key: ValueKey(event),
        controller: _c,
        initial: event,
        fixedDate: widget.dateIso,
        onDone: (saved) {
          setState(() => _editing = null);
          if (saved) unawaited(_load());
        },
      ),
    );
  }

  Future<void> _add() async {
    await showDialog<bool>(
      context: context,
      builder: (_) => EventForm(controller: _c, fixedDate: widget.dateIso),
    );
    unawaited(_load());
  }
}
