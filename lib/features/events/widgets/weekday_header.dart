import 'package:flutter/material.dart';

/// Sunday-first narrow weekday labels matching the calendar grid order.
/// Localised via [MaterialLocalizations].
class WeekdayHeader extends StatelessWidget {
  const WeekdayHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final labels = MaterialLocalizations.of(context).narrowWeekdays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          for (final wd in labels)
            Expanded(child: Text(wd, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}
