import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../../../domain/dates.dart';
import '../../../ui/glass.dart';
import '../../../ui/tones.dart';

/// Start time in the one app-wide format (locale + 24-hour system setting).
String formatStart(BuildContext context, int startMin) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: startMin ~/ 60, minute: startMin % 60),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// One event row: time, title, duration and notes; tap to edit.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, required this.onTap});

  final EventDto event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final weekly = event.source == EventSource.weekly;
    return GlassCard(
      radius: 20,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Text(
          formatStart(context, event.startMin),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: tones.time),
        ),
        title: Text(event.title),
        subtitle: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatDuration(event.durationSecs),
                style: TextStyle(color: tones.duration),
              ),
              if (event.context.isNotEmpty)
                TextSpan(
                  text: ' · ${event.context.split('\n').first}',
                  style: TextStyle(color: tones.muted),
                ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: weekly
            ? Icon(
                Icons.repeat,
                color: tones.weekly,
                semanticLabel: 'Repeats weekly',
              )
            : null,
      ),
    );
  }
}
