/// Date and time math shared by every feature. Pure Dart, no Flutter.
library;

/// `YYYY-MM-DD` for the local calendar day of [d].
String isoOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Local midnight of an `YYYY-MM-DD` string.
DateTime dateOf(String iso) {
  final d = DateTime.parse(iso);
  return DateTime(d.year, d.month, d.day);
}

/// Local midnight of [d].
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// [days] calendar days after [d] (DST-safe, unlike adding a [Duration]).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Moment [minutes] after local midnight of [day].
DateTime atMinute(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, 0, minutes);

/// `HH:MM`, 24-hour.
String hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

/// Next (or previous) quarter hour, wrapping around midnight.
int snapQuarter(int minutes, {required bool forward}) {
  final snapped = forward
      ? (minutes ~/ 15 + 1) * 15
      : ((minutes - 1) / 15).floor() * 15;
  return snapped % (24 * 60);
}

/// "15 min", "1 h", "1 h 30 min"; seconds only when under a minute.
String formatDuration(int seconds) {
  if (seconds < 60) return '$seconds s';
  final minutes = seconds ~/ 60;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}

final _durationPattern = RegExp(
  r'^\s*(?:(\d+)\s*h(?:ours?)?)?\s*(?:(\d+)\s*m(?:in)?)?\s*$',
  caseSensitive: false,
);

/// Seconds from user input: `45`, `45m`, `1h`, `1h30m`, `1:30`. Null when invalid or zero.
int? parseDuration(String raw) {
  final text = raw.trim();
  final colon = RegExp(r'^(\d+):(\d{2})$').firstMatch(text);
  final bare = int.tryParse(text);
  final int minutes;
  if (bare != null) {
    minutes = bare;
  } else if (colon != null) {
    final m = int.parse(colon.group(2)!);
    if (m >= 60) return null;
    minutes = int.parse(colon.group(1)!) * 60 + m;
  } else {
    final match = _durationPattern.firstMatch(text);
    if (match == null || (match.group(1) == null && match.group(2) == null)) {
      return null;
    }
    minutes =
        int.parse(match.group(1) ?? '0') * 60 +
        int.parse(match.group(2) ?? '0');
  }
  return minutes <= 0 ? null : minutes * 60;
}
