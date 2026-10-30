import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../domain/event_time.dart';
import '../../../ui/theme_helpers.dart';
import '../events_controller.dart';

/// Create / edit form for one event (also used for repeatables).
class EventForm extends StatefulWidget {
  const EventForm({
    super.key,
    required this.controller,
    this.initial,
    this.fixedDate,
    this.repeatable = false,
    this.onDone,
  });

  final EventsController controller;
  final EventDto? initial;
  final String? fixedDate;
  final bool repeatable;
  final ValueChanged<bool>? onDone;

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
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
        ? DateTime.parse(initial.dateIso)
        : widget.fixedDate != null
        ? DateTime.parse(widget.fixedDate!)
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

  String get _iso => isoOf(_date);
  String get _hm => hmOf(_time);

  /// TUI easter egg for past dates.
  bool get _inPast =>
      _iso.compareTo(isoOf(DateTime.now())) < 0 && widget.initial == null;

  void _fail(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      final String? error;
      if (widget.initial == null) {
        error = await widget.controller.createEvent(dto);
      } else {
        error = await widget.controller.updateEvent(
          widget.initial!.dateIso,
          widget.initial!.index,
          dto,
        );
      }
      if (error != null) {
        _fail(error);
        return;
      }
      if (mounted) {
        if (widget.onDone != null) {
          widget.onDone!(true);
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _fail(e.toString());
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
    final error = await widget.controller.deleteEvent(
      initial.dateIso,
      initial.index,
    );
    if (!mounted) return;
    if (error != null) {
      _fail(error);
      return;
    }
    if (widget.onDone != null) {
      widget.onDone!(true);
    } else {
      Navigator.pop(context, true);
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
              // Locked when creating into a tapped day; editing an
              // existing event may move it to another day (T1.1).
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
