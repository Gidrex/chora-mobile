import 'package:flutter/services.dart';

/// All-files access (shared chora_dir outside app dirs) + system folder picker.
/// Native side: MainActivity.
class StorageAccess {
  static const _channel = MethodChannel('dev.gidrex.chora_mobile/storage');

  static Future<bool> granted() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> request() =>
      _channel.invokeMethod('requestAllFilesAccess');

  /// System folder picker, resolved to a raw path on the primary volume.
  /// Null when cancelled, unsupported, or on a non-primary volume.
  static Future<String?> pickDirectory() async {
    try {
      return await _channel.invokeMethod<String>('pickDirectory');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
