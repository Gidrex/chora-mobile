import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The app PIN in Android Keystore-backed storage.
class PinStore {
  const PinStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'chora_pin';

  Future<bool> hasPin() async => (await _storage.read(key: _key)) != null;
  Future<void> setPin(String pin) => _storage.write(key: _key, value: pin);
  Future<bool> check(String pin) async =>
      (await _storage.read(key: _key)) == pin;
}
