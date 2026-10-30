import 'package:flutter/material.dart';
import 'platform/biometrics.dart';

import 'data/settings_store.dart';

/// Biometric-or-PIN gate used before opening protected notes and at startup.
Future<bool> unlock(
  BuildContext context,
  SettingsStore state, {
  required String reason,
}) async {
  if (state.biometricEnabled && await tryBiometrics(reason)) {
    return true;
  }
  if (!context.mounted) return false;
  if (!await state.hasPin()) {
    // No PIN set: biometrics off/failed and nothing to fall back to.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a PIN in Settings → Security first')),
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  return (await _pinSheet<bool>(context, state, reason, allowCancel: true)) ??
      false;
}

/// Returns entered PIN (setup mode) or bool (check mode).
Future<T?> _pinSheet<T>(
  BuildContext context,
  SettingsStore state,
  String reason, {
  required bool allowCancel,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: allowCancel,
    enableDrag: allowCancel,
    builder: (_) => _PinPad(state: state, reason: reason),
  );
}

/// PIN setup sheet. Returns the chosen PIN.
Future<String?> setupPin(BuildContext context, SettingsStore state) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (_) =>
        _PinPad(state: state, reason: 'Choose a 4-digit PIN', setup: true),
  );
}

/// PIN check sheet. Returns true when the PIN matches.
Future<bool?> checkPin(
  BuildContext context,
  SettingsStore state, {
  String reason = 'Enter PIN',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => _PinPad(state: state, reason: reason),
  );
}

/// Minimal lock screen: big round borderless digit buttons (Opal vibe).
class _PinPad extends StatefulWidget {
  const _PinPad({
    required this.state,
    required this.reason,
    this.setup = false,
  });

  final SettingsStore state;
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
    final ok = await widget.state.checkPin(_pin);
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
            for (final row in [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', '<'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final digit in row)
                    digit.isEmpty
                        ? const SizedBox(width: 76, height: 76)
                        : Padding(
                            padding: const EdgeInsets.all(6),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => digit == '<'
                                  ? setState(
                                      () => _pin = _pin.isEmpty
                                          ? ''
                                          : _pin.substring(0, _pin.length - 1),
                                    )
                                  : _press(digit),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: Center(
                                  child: Text(
                                    digit,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                ),
                              ),
                            ),
                          ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen app lock for the `open` threshold.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.state, required this.onUnlocked});

  final SettingsStore state;
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (await unlock(context, widget.state, reason: 'Unlock Chora')) {
      widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Chora', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _tryBiometric,
                child: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
