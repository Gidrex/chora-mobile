import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../data/notes_repository.dart';
import '../../../domain/event_time.dart';
import '../events_controller.dart';
import 'event_card.dart';

/// Chronological list of days with event cards.
class EventList extends StatefulWidget {
  const EventList({super.key, required this.controller});

  final EventsController controller;

  @override
  State<EventList> createState() => _EventListState();
}

class _EventListState extends State<EventList> {
  late String _iso = todayIso();
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
      final day = await widget.controller.loadDay(_iso);
      if (mounted) setState(() => _day = day);
    } on NotesFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(DateTime date) {
    setState(() => _iso = isoOf(date));
    unawaited(_load());
  }

  void _shiftWeek(int days) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: days));
      _iso = isoOf(dateOf(_iso).add(Duration(days: days)));
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = dateOf(_iso);
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
                    EventCard(event: event, day: date),
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
