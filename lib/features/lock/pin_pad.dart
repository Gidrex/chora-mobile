import 'package:flutter/material.dart';

import '../../platform/pin_store.dart';

/// PIN setup sheet: asks twice, returns the PIN or null when dismissed.
Future<String?> setupPin(BuildContext context, PinStore pins) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _PinPad(pins: pins, reason: 'Choose a 4-digit PIN', setup: true),
    );

/// PIN check sheet: true when the PIN matched.
Future<bool> checkPin(
  BuildContext context,
  PinStore pins,
  String reason,
) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PinPad(pins: pins, reason: reason),
    ) ??
    false;

/// Four-digit pad with big round borderless buttons.
class _PinPad extends StatefulWidget {
  const _PinPad({required this.pins, required this.reason, this.setup = false});

  final PinStore pins;
  final String reason;
  final bool setup;

  @override
  State<_PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<_PinPad> {
  String _pin = '';
  String? _first;
  String? _error;

  Future<void> _press(String digit) async {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length < 4) return;
    if (widget.setup) {
      if (_first == null) {
        setState(() {
          _first = _pin;
          _pin = '';
          _error = null;
        });
        return;
      }
      if (_pin == _first) {
        if (mounted) Navigator.pop(context, _pin);
      } else {
        setState(() {
          _error = 'Mismatch, try again';
          _first = null;
          _pin = '';
        });
      }
      return;
    }
    final ok = await widget.pins.check(_pin);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _error = 'Wrong PIN';
        _pin = '';
      });
    }
  }

  void _delete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final dots = List.generate(
      4,
      (i) => Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i < _pin.length
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _first != null ? 'Repeat the PIN' : widget.reason,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: dots),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', 'del'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final key in row)
                    _Key(
                      label: key,
                      onTap: switch (key) {
                        '' => null,
                        'del' => _delete,
                        _ => () => _press(key),
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return const SizedBox(width: 76, height: 76);
    final style = Theme.of(context).textTheme.headlineMedium;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Semantics(
        button: true,
        label: label == 'del' ? 'Delete digit' : label,
        excludeSemantics: true,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: label == 'del'
                  ? const Icon(Icons.backspace_outlined)
                  : Text(label, style: style),
            ),
          ),
        ),
      ),
    );
  }
}
