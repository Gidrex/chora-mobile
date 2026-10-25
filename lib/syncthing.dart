import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Local Syncthing daemon REST (127.0.0.1:8384) + native start/stop channel.
///
/// The daemon binary itself (`libsyncthing.so`) is bundled under
/// `android/app/src/main/jniLibs/`; when it is missing every call
/// surfaces a readable error instead of crashing.
class Syncthing {
  static const _channel = MethodChannel('dev.gidrex.chora_mobile/syncthing');
  static const _base = 'http://127.0.0.1:8384';

  static Future<String> get apiKey async =>
      (await _secureKeyReader()) ?? 'CHORA_LOCAL_KEY';

  static Future<String?> Function() _secureKeyReader = () async => null;
  static void bindKeyReader(Future<String?> Function() reader) {
    _secureKeyReader = reader;
  }

  static Future<Map<String, String>> get _headers async => {
    'X-API-Key': await apiKey,
  };

  /// Ask Kotlin to start the foreground daemon for [choraDir].
  static Future<void> start(String choraDir, String key) {
    return _channel.invokeMethod('start', {
      'choraDir': choraDir,
      'apiKey': key,
    });
  }

  static Future<void> stop() async {
    await _channel.invokeMethod('stop', {'apiKey': await apiKey});
  }

  static Future<bool> isRunning() async {
    try {
      final running = await _channel.invokeMethod<bool>('isRunning');
      return running ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<Map<String, dynamic>> status() async {
    final res = await http
        .get(Uri.parse('$_base/rest/system/status'), headers: await _headers)
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw Exception('status ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<String> myId() async {
    final status = await Syncthing.status();
    return status['myID'] as String? ?? '';
  }

  static Future<int> peerCount() async {
    final res = await http
        .get(
          Uri.parse('$_base/rest/system/connections'),
          headers: await _headers,
        )
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return 0;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final conns = (body['connections'] as Map<String, dynamic>?) ?? {};
    return conns.entries
        .where((e) => (e.value as Map<String, dynamic>)['connected'] == true)
        .length;
  }

  static Future<Map<String, dynamic>> config() async {
    final res = await http
        .get(Uri.parse('$_base/rest/config'), headers: await _headers)
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw Exception('config ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Add [deviceId] to devices + the `chora-root` folder, then push config.
  static Future<void> linkDevice(String deviceId) async {
    deviceId = deviceId.trim();
    if (deviceId.isEmpty) throw Exception('empty device ID');
    final cfg = await config();
    final devices = (cfg['devices'] as List).cast<Map<String, dynamic>>();
    if (!devices.any((d) => d['deviceID'] == deviceId)) {
      devices.add({
        'deviceID': deviceId,
        'name': 'pc',
        'compression': 'metadata',
        'introducer': false,
        'addresses': ['dynamic'],
      });
    }
    final folders = (cfg['folders'] as List).cast<Map<String, dynamic>>();
    for (final folder in folders) {
      if (folder['id'] == 'chora-root') {
        final devs = (folder['devices'] as List).cast<Map<String, dynamic>>();
        if (!devs.any((d) => d['deviceID'] == deviceId)) {
          devs.add({'deviceID': deviceId});
        }
      }
    }
    final put = await http
        .put(
          Uri.parse('$_base/rest/config'),
          headers: {...await _headers, 'Content-Type': 'application/json'},
          body: jsonEncode(cfg),
        )
        .timeout(const Duration(seconds: 5));
    if (put.statusCode != 200) throw Exception('config push ${put.statusCode}');
    await http
        .post(Uri.parse('$_base/rest/system/restart'), headers: await _headers)
        .timeout(const Duration(seconds: 5));
  }

  static Future<List<String>> linkedDevices() async {
    try {
      final cfg = await config();
      final devices = (cfg['devices'] as List).cast<Map<String, dynamic>>();
      return devices.map((d) => d['deviceID'] as String? ?? '').toList();
    } catch (_) {
      return [];
    }
  }
}
