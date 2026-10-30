import 'package:flutter/material.dart';

import 'bento_tile.dart';

/// Delegate-to-agent / record-as-event switch tiles.
class BentoGrid extends StatelessWidget {
  const BentoGrid({
    super.key,
    required this.delegate,
    required this.asEvent,
    required this.onDelegate,
    required this.onAsEvent,
  });

  final bool delegate;
  final bool asEvent;
  final ValueChanged<bool> onDelegate;
  final ValueChanged<bool> onAsEvent;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.0,
      children: [
        BentoTile(
          title: 'Delegate to Agent',
          subtitle: '-> to-agent/',
          value: delegate,
          onChanged: onDelegate,
        ),
        BentoTile(
          title: 'Record as Event',
          subtitle: 'events/*.md',
          value: asEvent,
          onChanged: onAsEvent,
        ),
      ],
    );
  }
}
