import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../platform/biometrics.dart';
import 'pin_pad.dart';

/// Ask for biometrics, then the PIN, before showing content of [level].
/// Returns true at once when [level] is not locked this session.
Future<bool> unlock(
  BuildContext context,
  SecurityLevel level, {
  required String reason,
}) async {
  final services = AppScope.of(context);
  if (!services.lock.locked(level)) return true;
  var ok = services.settings.biometricEnabled && await tryBiometrics(reason);
  if (!ok && context.mounted) {
    if (!await services.pins.hasPin()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Set a PIN in Settings first')),
        );
      }
      return false;
    }
    if (!context.mounted) return false;
    ok = await checkPin(context, services.pins, reason);
  }
  if (ok) services.lock.grant(level);
  return ok;
}
