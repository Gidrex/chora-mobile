import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../domain/event_time.dart';
import '../../../ui/theme_helpers.dart';

/// Day-timeline event card with accent border, glow and 12-hour time.
class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, required this.day});

  final EventDto event;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _capsuleFor(event.title, _accentsOf(context));
    final start = parseHm(event.timeHhmm);
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
                start == null ? event.timeHhmm : format12(start),
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
                    humanDuration(event.durationStr),
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
