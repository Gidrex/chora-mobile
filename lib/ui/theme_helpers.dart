import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Per-preset accent set for event capsules (borders, dots, glows).
/// The only non-scheme colors in the UI; everything reads them from here.
@immutable
class EventPalette extends ThemeExtension<EventPalette> {
  const EventPalette(this.accents);

  final List<Color> accents;

  @override
  EventPalette copyWith({List<Color>? accents}) =>
      EventPalette(accents ?? this.accents);

  @override
  EventPalette lerp(ThemeExtension<EventPalette>? other, double t) {
    if (other is! EventPalette || other.accents.length != accents.length) {
      return this;
    }
    return EventPalette([
      for (var i = 0; i < accents.length; i++)
        Color.lerp(accents[i], other.accents[i], t)!,
    ]);
  }
}

/// Mono style for paths, levels, times and autocomplete (SPEC typography rule).
TextStyle mono(BuildContext context, {double? size}) {
  final base = Theme.of(context).textTheme.bodyMedium;
  return GoogleFonts.ibmPlexMono(textStyle: base, fontSize: size ?? 12.5);
}

/// Small metadata badge: `09:00`, `45m`, `[restricted]`.
Widget badge(
  BuildContext context,
  String text, {
  Color? color,
  Widget? leading,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color ?? scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 2)],
        Text(text, style: mono(context, size: 11)),
      ],
    ),
  );
}

/// Security badge color: open neutral, restricted tertiary, critical error.
Widget securityBadge(BuildContext context, String level) {
  final scheme = Theme.of(context).colorScheme;
  final Color? color = switch (level) {
    'restricted' => scheme.tertiary.withValues(alpha: 0.25),
    'critical' => scheme.error.withValues(alpha: 0.25),
    _ => null,
  };
  return badge(
    context,
    '[$level]',
    color: color,
    leading: level == 'critical' ? const Icon(Icons.lock, size: 11) : null,
  );
}
