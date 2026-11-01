import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../domain/security.dart';
import '../../ui/tones.dart';
import '../../ui/widgets.dart';
import '../lock/pin_pad.dart';
import '../lock/unlock.dart';
import 'snack.dart';
import 'tone_section.dart';

/// Lock threshold, biometrics and the PIN.
class SecuritySection extends StatefulWidget {
  const SecuritySection({super.key});

  @override
  State<SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<SecuritySection> {
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPin());
  }

  Future<void> _loadPin() async {
    final has = await AppScope.of(context).pins.hasPin();
    if (mounted) setState(() => _hasPin = has);
  }

  /// Weakening protection or replacing the PIN needs the current unlock,
  /// otherwise anyone holding the phone could bypass the gate here.
  Future<bool> _confirmed() => unlock(
    context,
    SecurityLevel.critical,
    reason: 'Confirm security change',
  );

  Future<void> _setThreshold(SecurityThreshold next) async {
    final services = AppScope.of(context);
    if (next == services.settings.securityThreshold) return;
    if (_hasPin && !await _confirmed()) return;
    if (!mounted) return;
    if (next != SecurityThreshold.none && !_hasPin) {
      // A gated level without a PIN could lock the user out.
      final pin = await setupPin(context, services.pins);
      if (pin == null) return;
      await services.pins.setPin(pin);
      setState(() => _hasPin = true);
    }
    await services.settings.setSecurityThreshold(next);
  }

  Future<void> _changePin() async {
    final pins = AppScope.of(context).pins;
    if (_hasPin && !await _confirmed()) return;
    if (!mounted) return;
    final pin = await setupPin(context, pins);
    if (pin == null) return;
    await pins.setPin(pin);
    if (!mounted) return;
    setState(() => _hasPin = true);
    showSnack(context, 'PIN saved');
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ToneSection(
      title: 'Security',
      tone: Tones.of(context).heading,
      children: [
        RadioGroup<SecurityThreshold>(
          groupValue: settings.securityThreshold,
          onChanged: (v) {
            if (v != null) unawaited(_setThreshold(v));
          },
          child: Column(
            children: [
              for (final t in SecurityThreshold.values)
                RadioListTile<SecurityThreshold>(
                  value: t,
                  title: Text(t.label),
                  subtitle: Text(t.explanation),
                ),
            ],
          ),
        ),
        SwitchRow(
          icon: Icons.fingerprint,
          title: 'Unlock with fingerprint',
          value: settings.biometricEnabled,
          onChanged: settings.setBiometricEnabled,
        ),
        EvenRow(
          icon: Icons.pin_outlined,
          title: _hasPin ? 'Change PIN' : 'Set PIN',
          onTap: _changePin,
        ),
      ],
    );
  }
}
