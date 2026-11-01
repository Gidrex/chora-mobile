import 'package:chora_mobile/data/models.dart';
import 'package:chora_mobile/features/events/widgets/event_tile.dart';
import 'package:chora_mobile/ui/theme.dart';
import 'package:chora_mobile/ui/tones.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('event tile colors time, duration and weekly by tone', (
    tester,
  ) async {
    const event = EventDto(
      title: 'Gym',
      dateIso: '2026-11-02',
      startMin: 19 * 60,
      durationSecs: 3600,
      context: 'Legs',
      source: EventSource.weekly,
      index: 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          preset: 'ambient',
          brightness: Brightness.dark,
          fontName: 'Onest',
        ),
        home: Scaffold(
          body: EventTile(event: event, onTap: () {}),
        ),
      ),
    );
    final context = tester.element(find.byType(EventTile));
    final tones = Tones.of(context);
    final time = tester.widget<Text>(
      find.text(formatStart(context, event.startMin)),
    );
    expect(time.style?.color, tones.time);
    final weekly = tester.widget<Icon>(find.byIcon(Icons.repeat));
    expect(weekly.color, tones.weekly);
  });
}
