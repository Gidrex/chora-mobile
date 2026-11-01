import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/boot_error.dart';
import 'app/services.dart';
import 'data/vault_session.dart';
import 'src/rust/frb_generated.dart';

/// Boot: bridge + prefs + storage, then the first frame. Everything else
/// (reminders, permission prompts, sync checks) runs after it.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled assets; the app never touches the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  await RustLib.init();
  await _start();
}

Future<void> _start() async {
  final prefs = await SharedPreferences.getInstance();
  try {
    runApp(ChoraApp(services: await AppServices.boot(prefs)));
  } on AppFailure catch (e) {
    runApp(BootError(prefs: prefs, message: e.message, onRetry: _start));
  }
}
