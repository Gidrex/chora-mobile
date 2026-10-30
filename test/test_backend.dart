import 'dart:io';

import 'package:chora_mobile/backend.dart';
import 'package:chora_mobile/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart'
    show ExternalLibrary;

bool _ready = false;

/// Real backend in a temp dir for widget tests (`flutter test` does not
/// bundle the Rust lib, so load it explicitly; build it via `cargo build`
/// in `rust/` after any `api.rs` change).
Future<String> initTestBackend() async {
  if (!_ready) {
    const so = 'rust/target/debug/libchora_mobile_rust.so';
    if (!File(so).existsSync()) {
      throw StateError('missing $so: run `cargo build` in rust/ first');
    }
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(File(so).absolute.path),
    );
    _ready = true;
  }
  final tmp = await Directory.systemTemp.createTemp('chora_test');
  await initStorage(rootDir: tmp.path);
  Backend.root = tmp.path;
  return tmp.path;
}
