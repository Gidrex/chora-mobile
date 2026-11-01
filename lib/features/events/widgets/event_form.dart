import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../domain/dates.dart';
import '../../../domain/events_view.dart';
import '../../../ui/widgets.dart';
import '../events_controller.dart';
import 'duration_field.dart';
import 'event_tile.dart';

/// How the event form was closed.
enum FormOutcome { saved, deleteRequested, stale }

/// Full-screen form for a new event ([original] null) or an existing one.
class EventFormPage extends StatefulWidget {
  const EventFormPage({
    super.key,
    required this.controller,
    required this.date,
    this.original,
    this.weekly = false,
  });

  final EventsController controller;
  final DateTime date;
  final EventDto? original;
  final bool weekly;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  late final EventDto _initial;
  late final _title = TextEditingController(text: _initial.title);
  late final _notes = TextEditingController(text: _initial.context);
  final _custom = TextEditingController();
  late DateTime _date = dateOf(_initial.dateIso);
  late int _start = _initial.startMin;
  late int? _duration = _initial.durationSecs;
  late bool _weekly = _initial.source == EventSource.weekly;
  bool _titleTouched = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _initial =
        widget.original ??
        EventDto(
          title: '',
          dateIso: isoOf(widget.date),
          startMin: snapQuarter(now.hour * 60 + now.minute, forward: true),
          durationSecs: 30 * 60,
          context: '',
          source: widget.weekly ? EventSource.weekly : EventSource.day,
          index: 0,
        );
    if (!durationPresets.contains(_duration)) {
      _custom.text = formatDuration(_initial.durationSecs);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _custom.dispose();
    super.dispose();
  }

  EventDto get _draft => EventDto(
    title: _title.text.trim(),
    dateIso: isoOf(_date),
    startMin: _start,
    durationSecs: _duration ?? 0,
    context: _notes.text.trim(),
    source: _weekly ? EventSource.weekly : EventSource.day,
    index: _initial.index,
  );

  bool get _valid => _title.text.trim().isNotEmpty && _duration != null;
  bool get _dirty => _draft != _initial;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final message = await widget.controller.save(
      original: widget.original,
      updated: _draft,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (message == null) return Navigator.pop(context, FormOutcome.saved);
    if (message == EventsController.changedMessage) {
      return Navigator.pop(context, FormOutcome.stale);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onPop(bool didPop, Object? _) async {
    if (didPop) return;
    final choice = await confirmUnsavedEdits(context);
    if (!mounted) return;
    switch (choice) {
      case DiscardChoice.save:
        await _save();
      case DiscardChoice.discard:
        Navigator.pop(context);
      case null:
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start ~/ 60, minute: _start % 60),
    );
    if (picked == null) return;
    setState(() => _start = picked.hour * 60 + picked.minute);
  }

  void _preset(int seconds) => setState(() {
    _custom.clear();
    _duration = seconds;
  });

  @override
  Widget build(BuildContext context) {
    final editing = widget.original != null;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing ? 'Edit event' : 'New event'),
          actions: [
            if (editing)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete event',
                onPressed: () =>
                    Navigator.pop(context, FormOutcome.deleteRequested),
              ),
            TextButton(
              onPressed: _valid && !_saving ? _save : null,
              child: const Text('Save'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TitleField(
              controller: _title,
              autofocus: !editing,
              showError: _titleTouched && _title.text.trim().isEmpty,
              onChanged: () => setState(() => _titleTouched = true),
            ),
            const SizedBox(height: 8),
            _WhenTiles(
              date: _date,
              start: _start,
              weekly: _weekly,
              onDate: _pickDate,
              onTime: _pickTime,
              onWeekly: (v) => setState(() => _weekly = v),
            ),
            const SizedBox(height: 8),
            DurationField(
              seconds: _duration,
              custom: _custom,
              onPreset: _preset,
              onCustom: (t) => setState(() => _duration = parseDuration(t)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              minLines: 3,
              maxLines: null,
              onChanged: (_) => setState(() {}),
              decoration: _notesDecoration,
            ),
          ],
        ),
      ),
    );
  }
}

const _notesDecoration = InputDecoration(
  labelText: 'Notes',
  border: OutlineInputBorder(),
  alignLabelWithHint: true,
);

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.autofocus,
    required this.showError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool autofocus;
  final bool showError;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: 'Title',
        border: const OutlineInputBorder(),
        errorText: showError ? 'Add a title' : null,
      ),
    );
  }
}

/// Date (or weekday) and start time rows; they wrap, never truncate.
class _WhenTiles extends StatelessWidget {
  const _WhenTiles({
    required this.date,
    required this.start,
    required this.weekly,
    required this.onDate,
    required this.onTime,
    required this.onWeekly,
  });

  final DateTime date;
  final int start;
  final bool weekly;
  final VoidCallback onDate;
  final VoidCallback onTime;
  final ValueChanged<bool> onWeekly;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final day = l10n.formatFullDate(date);
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today_outlined),
          title: Text(weekly ? 'Every ${day.split(',').first}' : day),
          onTap: onDate,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.schedule),
          title: Text(formatStart(context, start)),
          onTap: onTime,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Repeats weekly'),
          value: weekly,
          onChanged: onWeekly,
        ),
      ],
    );
  }
}
