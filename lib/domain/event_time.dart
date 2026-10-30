import 'package:flutter/material.dart';

/// Time parsing/formatting for event forms and lists (no Flutter widgets,
/// no I/O). Behavior-preserving move out of the events screen.

TimeOfDay? parseHm(String raw) {
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Minutes from strings like `45m`, `1h`, `1h30m`.
int? parseMinutes(String raw) {
  final match = RegExp(
    r'^\s*(?:(\d+)\s*h)?\s*(?:(\d+)\s*m)?\s*$',
  ).firstMatch(raw);
  if (match == null) return null;
  final total =
      (int.tryParse(match.group(1) ?? '0') ?? 0) * 60 +
      (int.tryParse(match.group(2) ?? '0') ?? 0);
  return total == 0 ? null : total;
}

String format12(TimeOfDay t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// `1 hour 30 minutes` from `1h30m` (falls back to the raw string).
String humanDuration(String raw) {
  final mins = parseMinutes(raw);
  if (mins == null) return raw;
  final parts = <String>[];
  final hours = mins ~/ 60;
  final minutes = mins % 60;
  if (hours > 0) parts.add('$hours hour${hours == 1 ? '' : 's'}');
  if (minutes > 0) parts.add('$minutes minute${minutes == 1 ? '' : 's'}');
  return parts.join(' ');
}

/// Today's date as `YYYY-MM-DD` (bridge-free; mirrors `Backend.isoOf`).
String todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// `YYYY-MM-DD` (bridge-free; mirrors `Backend.isoOf`).
String isoOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Parse back what [isoOf] produced.
DateTime dateOf(String iso) => DateTime.parse(iso);

/// `HH:MM` 24-hour rendering.
String hmOf(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
