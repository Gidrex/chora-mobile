import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/settings_store.dart';

/// Shown when the configured storage folder cannot be opened.
class BootError extends StatelessWidget {
  const BootError({
    super.key,
    required this.prefs,
    required this.message,
    required this.onRetry,
  });

  final SharedPreferences prefs;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.folder_off_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  "Can't open the storage folder",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    await SettingsStore(prefs).setStoragePath(null);
                    await onRetry();
                  },
                  child: const Text('Use the app folder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
