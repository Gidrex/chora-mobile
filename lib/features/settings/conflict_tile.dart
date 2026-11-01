import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../ui/tones.dart';

/// One sync conflict copy with its two resolutions.
class ConflictTile extends StatelessWidget {
  const ConflictTile({
    super.key,
    required this.conflict,
    required this.onResolve,
  });

  final ConflictDto conflict;
  final ValueChanged<ConflictChoice> onResolve;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_problem, color: scheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Sync conflict in ',
                    children: [
                      TextSpan(
                        text: conflict.original,
                        style: TextStyle(color: Tones.of(context).file),
                      ),
                    ],
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () => onResolve(ConflictChoice.keepCurrent),
                child: const Text('Keep current'),
              ),
              TextButton(
                onPressed: () => onResolve(ConflictChoice.keepCopy),
                child: const Text('Keep copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
