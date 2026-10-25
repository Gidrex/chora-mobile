import 'dart:io';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../auth.dart';
import '../backend.dart';
import '../storage_access.dart';
import '../theme.dart';

/// Appearance + Security + Storage.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.state,
    required this.onRootChanged,
    required this.onAppearanceChanged,
  });

  final AppState state;
  final Future<void> Function() onRootChanged;
  final VoidCallback onAppearanceChanged;

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  List<String> _conflicts = [];
  bool _hasPin = false;
  bool _hasAccess = false;
  String _policy = 'backlog';
  late final AppLifecycleListener _resumed;

  @override
  void initState() {
    super.initState();
    _resumed = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _resumed.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final hasPin = await widget.state.hasPin();
    final hasAccess = await StorageAccess.granted();
    List<String> conflicts = [];
    try {
      conflicts = await Backend.conflicts();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _hasAccess = hasAccess;
        _conflicts = conflicts;
      });
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card('Appearance', [
            _pad(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Palette'),
                  const SizedBox(height: 8),
                  _presetButtons(s),
                ],
              ),
            ),
            _pad(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme'),
                  const SizedBox(height: 8),
                  _modeButtons(s),
                ],
              ),
            ),
            _pad(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Font'),
                  RadioGroup<String>(
                    groupValue: s.fontName,
                    onChanged: (v) async {
                      if (v == null) return;
                      await s.setFontName(v);
                      widget.onAppearanceChanged();
                    },
                    child: Column(
                      children: [
                        for (final font in [
                          'Onest',
                          'Golos Text',
                          'Martian Mono',
                          'IBM Plex Mono',
                        ])
                          RadioListTile<String>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(font),
                            value: font,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _switchRow(
              icon: Icons.event_repeat,
              title: 'Show repeatable on grid',
              value: s.showRepeat,
              onChanged: (v) => s.setShowRepeat(v),
            ),
            _switchRow(
              icon: Icons.grid_view,
              title: 'Square cells',
              value: s.fixedCells,
              onChanged: (v) => s.setFixedCells(v),
            ),
          ]),
          _card('Security', [
            _pad(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PIN / biometric threshold'),
                  const SizedBox(height: 8),
                  _thresholdButtons(s),
                ],
              ),
            ),
            _switchRow(
              icon: Icons.fingerprint,
              title: 'Fingerprint unlock',
              value: s.biometricEnabled,
              onChanged: (v) => s.setBiometricEnabled(v),
            ),
            _row(
              icon: Icons.lock,
              title: _hasPin ? 'Change PIN' : 'Set PIN',
              trailing: _hasPin
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                final pin = await setupPin(context, s);
                if (pin != null) {
                  await s.setPin(pin);
                  _snack('PIN saved');
                  _refresh();
                }
              },
            ),
          ]),
          _card('Storage & Maintenance', [
            if (_conflicts.isNotEmpty)
              _pad(
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sync conflicts:'),
                      for (final path in _conflicts)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                path.split('/').last,
                                style: mono(context, size: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _resolveConflict(path, keepMine: true),
                              child: const Text('Mine'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _resolveConflict(path, keepMine: false),
                              child: const Text('Theirs'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            _row(
              icon: Icons.sd_storage,
              title: 'All files access',
              trailing: _hasAccess
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                await StorageAccess.request();
                _refresh();
              },
            ),
            _pad(Text(Backend.root, style: mono(context, size: 11))),
            _row(
              icon: Icons.folder_open,
              title: 'Change chora_dir path',
              onTap: _changeRoot,
            ),
            _row(
              icon: Icons.history,
              title: 'Old events',
              trailing: DropdownButton<String>(
                value: _policy,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'nothing', child: Text('Nothing')),
                  DropdownMenuItem(value: 'backlog', child: Text('Backlog')),
                  DropdownMenuItem(value: 'delete', child: Text('Delete')),
                ],
                onChanged: (v) => setState(() => _policy = v ?? 'backlog'),
              ),
            ),
            _pad(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        final summary = await sweepOldEvents(
                          rootDir: Backend.root,
                          policy: _policy,
                        );
                        _snack(summary);
                      } catch (e) {
                        _snack(Backend.errMsg(e));
                      }
                    },
                    child: const Text('Clean up old days now'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await seedDemo(Backend.root);
                      _snack('Demo data ready');
                    },
                    child: const Text('Load demo data'),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: 60, endIndent: 16));
      }
      rows.add(children[i]);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }

  /// Ref-style row: icon tile + title + trailing (chevron by default).
  Widget _row({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: _tile(icon),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    return ListTile(
      leading: _tile(icon),
      title: Text(title),
      trailing: Switch(value: value, onChanged: enabled ? onChanged : null),
      onTap: enabled ? () => onChanged(!value) : null,
    );
  }

  Widget _tile(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20),
    );
  }

  /// Padded non-row content inside a group (chips, segmented, radios).
  Widget _pad(Widget child) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: child,
    );
  }

  Widget _presetButtons(AppState s) {
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in {
          'system': 'System Dynamic',
          'obsidian': 'Opal Obsidian',
          'luma': 'Luma Warm',
          'mono': 'Monochrome Ink',
        }.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: s.themePreset == entry.key,
            onSelected: (_) async {
              await s.setThemePreset(entry.key);
              widget.onAppearanceChanged();
            },
          ),
      ],
    );
  }

  Widget _modeButtons(AppState s) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.system, label: Text('System')),
        ButtonSegment(value: ThemeMode.light, label: Text('Light')),
        ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
      ],
      selected: {s.themeMode},
      onSelectionChanged: (v) async {
        await s.setThemeMode(v.first);
        widget.onAppearanceChanged();
      },
    );
  }

  Widget _thresholdButtons(AppState s) {
    return Wrap(
      spacing: 8,
      children: [
        for (final t in ['none', 'open', 'restricted', 'critical'])
          ChoiceChip(
            label: Text(t, style: mono(context)),
            selected: s.securityThreshold == t,
            onSelected: (_) => s.setSecurityThreshold(t),
          ),
      ],
    );
  }

  Future<void> _resolveConflict(String path, {required bool keepMine}) async {
    try {
      final conflict = File(path);
      final marker = '.sync-conflict-';
      final at = path.indexOf(marker);
      if (at < 0) throw Exception('not a conflict file');
      final tail = path.substring(at + marker.length);
      final dash = tail.indexOf('.');
      final ext = dash >= 0 ? tail.substring(dash) : '';
      final original = File(path.substring(0, at) + ext);
      if (keepMine) {
        await conflict.delete();
      } else {
        await conflict.rename(original.path);
      }
      _snack(keepMine ? 'Kept mine' : 'Kept theirs');
      _refresh();
    } catch (e) {
      _snack(Backend.errMsg(e));
    }
  }

  Future<void> _changeRoot() async {
    final next = await StorageAccess.pickDirectory() ?? await _manualRoot();
    if (next == null) return;
    if (next.isEmpty) {
      await widget.state.setRootDir(null);
    } else {
      await widget.state.setRootDir(next);
    }
    await widget.onRootChanged();
  }

  Future<String?> _manualRoot() async {
    final controller = TextEditingController(
      text: widget.state.rootDirOverride ?? Backend.root,
    );
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('chora_dir path'),
        content: TextField(controller: controller, style: mono(ctx)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return next;
  }
}
