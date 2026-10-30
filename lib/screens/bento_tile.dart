import 'package:flutter/material.dart';

import '../ui/theme_helpers.dart';

/// Bento toggle tile: title + mono subtitle + switch. Tapping the tile
/// toggles it; the tile itself carries no semantics beyond the switch.
class BentoTile extends StatelessWidget {
  const BentoTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? scheme.primaryContainer : scheme.surfaceContainer,
          border: Border.all(color: scheme.outlineVariant, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Switch(value: value, onChanged: onChanged),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(subtitle, style: mono(context, size: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
