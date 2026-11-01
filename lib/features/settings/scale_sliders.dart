import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/settings_store.dart';
import '../../ui/tones.dart';
import '../../ui/widgets.dart';

typedef _Range = ({double min, double max});

/// "Text size" and "App scale" sliders. The dragged value stays local and is
/// saved on release, so the whole app re-zooms once, not on every tick.
class ScaleSliders extends StatefulWidget {
  const ScaleSliders({super.key, required this.appearance});

  final AppearanceSettings appearance;

  @override
  State<ScaleSliders> createState() => _ScaleSlidersState();
}

class _ScaleSlidersState extends State<ScaleSliders> {
  double? _text;
  double? _ui;

  @override
  Widget build(BuildContext context) {
    final a = widget.appearance;
    final text = _text ?? a.textScale;
    final ui = _ui ?? a.uiScale;
    return Column(
      children: [
        _ScaleRow(
          icon: Icons.format_size,
          title: 'Text size',
          value: text,
          range: AppearanceSettings.textScaleRange,
          onChanged: (v) => setState(() => _text = v),
          onChangeEnd: (v) async {
            await a.setTextScale(v);
            if (mounted) setState(() => _text = null);
          },
        ),
        _Preview(scale: text, saved: a.textScale),
        _ScaleRow(
          icon: Icons.zoom_in,
          title: 'App scale',
          value: ui,
          range: AppearanceSettings.uiScaleRange,
          onChanged: (v) => setState(() => _ui = v),
          onChangeEnd: (v) async {
            await a.setUiScale(v);
            if (mounted) setState(() => _ui = null);
          },
        ),
        if (a.textScale != 1 || a.uiScale != 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                unawaited(a.setTextScale(1));
                unawaited(a.setUiScale(1));
              },
              child: const Text('Reset'),
            ),
          ),
      ],
    );
  }
}

String _percent(double v) => '${(v * 100).round()}%';

/// Icon tile, title, value in the muted tone, and a stepped slider below.
class _ScaleRow extends StatelessWidget {
  const _ScaleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.range,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final IconData icon;
  final String title;
  final double value;
  final _Range range;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final steps = ((range.max - range.min) / 0.05).round();
    return Column(
      children: [
        ListTile(
          leading: IconTile(icon: icon),
          title: Text(title),
          trailing: Text(
            _percent(value),
            style: TextStyle(color: Tones.of(context).muted),
          ),
        ),
        Slider(
          value: value.clamp(range.min, range.max),
          min: range.min,
          max: range.max,
          divisions: steps,
          label: _percent(value),
          semanticFormatterCallback: _percent,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}

/// One line sized by the slider value, before it is applied app-wide.
class _Preview extends StatelessWidget {
  const _Preview({required this.scale, required this.saved});

  final double scale;
  final double saved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        'The quick brown fox jumps over the lazy dog',
        // The tree already carries system * saved; swap saved for the drag.
        textScaler: TextScaler.linear(
          MediaQuery.textScalerOf(context).scale(1) / saved * scale,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Tones.of(context).heading),
      ),
    );
  }
}
