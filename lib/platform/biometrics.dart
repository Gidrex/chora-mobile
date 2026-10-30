import 'package:local_auth/local_auth.dart';

/// Android biometric gate. Returns false on denial, missing hardware, or
/// any platform error; callers fall back to PIN.
Future<bool> tryBiometrics(String reason) async {
  try {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) return false;
    if (!await auth.canCheckBiometrics) return false;
    return await auth.authenticate(
      localizedReason: reason,
      biometricOnly: true,
    );
  } on Exception {
    return false;
  }
}
