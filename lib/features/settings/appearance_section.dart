import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/settings_store.dart';
import '../../ui/tones.dart';
import 'scale_sliders.dart';
import 'tone_section.dart';

/// Theme mode, color preset and font.
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = AppScope.of(context).settings.appearance;
    return ListenableBuilder(
      listenable: appearance,
      builder: (context, _) => ToneSection(
        title: 'Appearance',
        tone: Tones.of(context).folder,
        children: [
          ScaleSliders(appearance: appearance),
          _Labeled(
            label: 'Theme',
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('System'),
                  ),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Light')),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: FittedBox(fit: BoxFit.scaleDown, child: Text('Dark')),
                ),
              ],
              selected: {appearance.themeMode},
              onSelectionChanged: (v) => appearance.setThemeMode(v.first),
            ),
          ),
          _Labeled(
            label: 'Colors',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in ThemePreset.values)
                  ChoiceChip(
                    label: Text(preset.label),
                    selected: appearance.themePreset == preset,
                    onSelected: (_) => appearance.setThemePreset(preset),
                  ),
              ],
            ),
          ),
          _FontChoices(appearance: appearance),
        ],
      ),
    );
  }
}

/// Each font option is rendered in its own font.
class _FontChoices extends StatelessWidget {
  const _FontChoices({required this.appearance});

  final AppearanceSettings appearance;

  @override
  Widget build(BuildContext context) {
    return _Labeled(
      label: 'Font',
      child: RadioGroup<FontChoice>(
        groupValue: appearance.fontChoice,
        onChanged: (v) {
          if (v != null) unawaited(appearance.setFontChoice(v));
        },
        child: Column(
          children: [
            for (final font in FontChoice.values)
              RadioListTile<FontChoice>(
                contentPadding: EdgeInsets.zero,
                value: font,
                title: Text(
                  font.family,
                  style: TextStyle(fontFamily: font.family),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A caption above non-row content inside a section.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Tones.of(context).muted),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
