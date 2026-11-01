import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../platform/paths.dart';
import '../../platform/storage_access.dart';
import '../../ui/tones.dart';
import '../../ui/widgets.dart';
import 'conflict_tile.dart';
import 'snack.dart';
import 'storage_controller.dart';
import 'tone_section.dart';

/// Storage folder, sync conflicts, past events.
class StorageSection extends StatefulWidget {
  const StorageSection({super.key});

  @override
  State<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<StorageSection> {
  late final StorageController _controller;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _controller = StorageController(
      services.storage,
      services.session.revision,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (!await StorageAccess.granted()) {
      await StorageAccess.request();
      if (mounted) {
        showSnack(context, 'Allow access to all files, then tap Change again');
      }
      return;
    }
    final path = await StorageAccess.pickDirectory();
    if (path != null) await _switchTo(path, keep: path);
  }

  Future<void> _useAppFolder() async =>
      _switchTo(await defaultStoragePath(), keep: null);

  /// Open [path] first; persist the choice ([keep], null = app folder) only
  /// when it opened, so a bad folder never breaks the next launch.
  Future<void> _switchTo(String path, {required String? keep}) async {
    final error = await _controller.moveTo(path);
    if (!mounted) return;
    if (error != null) return showSnack(context, error);
    await AppScope.of(context).settings.setStoragePath(keep);
    if (mounted) showSnack(context, 'Storage folder changed');
  }

  Future<void> _sweep(OldEventPolicy policy) async {
    final delete = policy == OldEventPolicy.delete;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(delete ? 'Delete past days?' : 'Archive past days?'),
        content: Text(
          delete
              ? 'Day files before today are deleted. This cannot be undone.'
              : 'Day files before today move to the backlog folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(delete ? 'Delete' : 'Archive'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final message = await _controller.sweep(policy);
    if (mounted) showSnack(context, message);
  }

  Future<void> _resolve(ConflictDto c, ConflictChoice choice) async {
    final message = await _controller.resolve(c, choice);
    if (mounted) showSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final custom = AppScope.of(context).settings.storagePath != null;
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => ToneSection(
        title: 'Storage',
        tone: Tones.of(context).file,
        children: [
          ListTile(
            leading: const IconTile(icon: Icons.folder_outlined),
            title: const Text('Storage folder'),
            subtitle: Text(
              friendlyPath(_controller.root, isDefault: !custom),
              style: TextStyle(color: Tones.of(context).file),
            ),
            trailing: TextButton(
              onPressed: _change,
              child: const Text('Change'),
            ),
          ),
          if (custom)
            EvenRow(
              icon: Icons.phone_android,
              title: 'Use the app folder',
              onTap: _useAppFolder,
            ),
          if (_controller.error != null)
            ListTile(title: Text(_controller.error!)),
          for (final c in _controller.conflicts)
            ConflictTile(
              conflict: c,
              onResolve: (choice) => _resolve(c, choice),
            ),
          EvenRow(
            icon: Icons.archive_outlined,
            title: 'Archive past days',
            onTap: () => _sweep(OldEventPolicy.backlog),
          ),
          EvenRow(
            icon: Icons.delete_sweep_outlined,
            title: 'Delete past days',
            onTap: () => _sweep(OldEventPolicy.delete),
          ),
        ],
      ),
    );
  }
}
