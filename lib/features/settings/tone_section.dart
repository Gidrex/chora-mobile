import 'package:flutter/material.dart';

import '../../ui/glass.dart';

/// Themed card with a header in its own [tone] and divided rows.
/// Each settings section gets a different tone, so they read apart at a glance.
class ToneSection extends StatelessWidget {
  const ToneSection({
    super.key,
    required this.title,
    required this.tone,
    required this.children,
  });

  final String title;
  final Color tone;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: tone),
              ),
            ),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
