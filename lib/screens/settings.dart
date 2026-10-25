import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_state.dart';
import '../auth.dart';
import '../backend.dart';
import '../theme.dart';
import '../syncthing.dart';

/// Appearance + Security + Syncthing + Storage.
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
  String _stStatus = '';
  String _myId = '';
  List<String> _peers = [];
  List<String> _conflicts = [];
  bool _stBusy = false;
  bool _hasPin = false;
  String _policy = 'backlog';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final hasPin = await widget.state.hasPin();
    List<String> conflicts = [];
    try {
      conflicts = await Backend.conflicts();
    } catch (_) {}
    String status = '';
    String myId = '';
    List<String> peers = [];
    if (widget.state.stEnabled) {
      final running = await Syncthing.isRunning();
      if (running) {
        try {
          myId = await Syncthing.myId();
          final count = await Syncthing.peerCount();
          peers = await Syncthing.linkedDevices();
          status = 'Работает • Папка: chora-root • Онлайн: $count устр.';
        } catch (e) {
          status = 'Демон не отвечает: ${Backend.errMsg(e)}';
        }
      } else {
        status = 'Демон не запущен';
      }
    }
    if (mounted) {
      setState(() {
        _hasPin = hasPin;
        _conflicts = conflicts;
        _stStatus = status;
        _myId = myId;
        _peers = peers;
      });
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleSt(bool enable) async {
    setState(() => _stBusy = true);
    try {
      if (enable) {
        final key = await widget.state.stApiKey();
        await Syncthing.start(Backend.root, key);
        await widget.state.setStEnabled(true);
      } else {
        await Syncthing.stop();
        await widget.state.setStEnabled(false);
      }
    } catch (e) {
      _snack('Syncthing: ${Backend.errMsg(e)}');
      await widget.state.setStEnabled(false);
    } finally {
      if (mounted) setState(() => _stBusy = false);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card('Appearance', [
            const Text('Палитра'),
            const SizedBox(height: 8),
            _presetButtons(s),
            const SizedBox(height: 12),
            const Text('Тема'),
            _modeButtons(s),
            const SizedBox(height: 12),
            const Text('Шрифт'),
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
                      title: Text(font),
                      value: font,
                    ),
                ],
              ),
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Показывать Repeatable на сетке'),
              value: s.showRepeat,
              onChanged: (v) => s.setShowRepeat(v),
            ),
            SwitchListTile(
              dense: true,
              title: const Text('Квадратные ячейки'),
              value: s.fixedCells,
              onChanged: (v) => s.setFixedCells(v),
            ),
          ]),
          _card('Security', [
            const Text('Порог PIN / биометрии'),
            const SizedBox(height: 8),
            _thresholdButtons(s),
            SwitchListTile(
              dense: true,
              title: const Text('Разблокировка отпечатком пальца'),
              value: s.biometricEnabled,
              onChanged: (v) => s.setBiometricEnabled(v),
            ),
            ListTile(
              dense: true,
              title: Text(_hasPin ? 'Изменить PIN-код' : 'Установить PIN-код'),
              trailing: _hasPin
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
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
          _card('Syncthing (P2P)', [
            SwitchListTile(
              dense: true,
              title: const Text('Включить синхронизацию'),
              value: s.stEnabled,
              onChanged: _stBusy ? null : _toggleSt,
            ),
            if (_stStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_stStatus, style: mono(context)),
              ),
            if (_myId.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _myId,
                      style: mono(context, size: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Копировать',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _myId));
                      _snack('Device ID copied');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code, size: 18),
                    tooltip: 'Показать QR-код',
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Мой Device ID'),
                        content: QrImageView(data: _myId, size: 220),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Подключённые устройства (ПК):'),
              for (final peer in _peers)
                Text(
                  peer,
                  style: mono(context, size: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanAndLink,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('+ По QR'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _manualLink,
                      icon: const Icon(Icons.edit),
                      label: const Text('+ По ID'),
                    ),
                  ),
                ],
              ),
            ],
            if (_conflicts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Конфликты синхронизации:'),
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
                            child: const Text('Моя'),
                          ),
                          TextButton(
                            onPressed: () =>
                                _resolveConflict(path, keepMine: false),
                            child: const Text('Их'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ]),
          _card('Storage & Maintenance', [
            Text(Backend.root, style: mono(context, size: 11)),
            TextButton(
              onPressed: _changeRoot,
              child: const Text('Изменить путь к chora_dir'),
            ),
            Row(
              children: [
                const Text('Старые события: '),
                DropdownButton<String>(
                  value: _policy,
                  items: const [
                    DropdownMenuItem(value: 'nothing', child: Text('Nothing')),
                    DropdownMenuItem(value: 'backlog', child: Text('Backlog')),
                    DropdownMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onChanged: (v) => setState(() => _policy = v ?? 'backlog'),
                ),
              ],
            ),
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
              child: const Text('Очистить старые дни сейчас'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await seedDemo(Backend.root);
                _snack('Demo data ready');
              },
              child: const Text('Загрузить демо-данные'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
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

  Future<void> _scanAndLink() async {
    if (!await Permission.camera.request().isGranted) {
      _snack('Camera permission denied');
      return;
    }
    if (!mounted) return;
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (id == null || id.isEmpty) return;
    try {
      await Syncthing.linkDevice(id);
      _snack('Device linked');
      _refresh();
    } catch (e) {
      _snack(Backend.errMsg(e));
    }
  }

  Future<void> _manualLink() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Device ID компьютера'),
        content: TextField(
          controller: controller,
          style: mono(ctx, size: 12),
          decoration: const InputDecoration(hintText: 'XXXXXXX-...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Привязать'),
          ),
        ],
      ),
    );
    if (id == null || id.isEmpty) return;
    try {
      await Syncthing.linkDevice(id);
      _snack('Device linked');
      _refresh();
    } catch (e) {
      _snack(Backend.errMsg(e));
    }
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
    final controller = TextEditingController(
      text: widget.state.rootDirOverride ?? Backend.root,
    );
    final next = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Путь к chora_dir'),
        content: TextField(controller: controller, style: mono(ctx)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (next == null) return;
    if (next.isEmpty) {
      await widget.state.setRootDir(null);
    } else {
      await widget.state.setRootDir(next);
    }
    await widget.onRootChanged();
  }
}

/// Full-screen QR scanner returning the scanned Device ID.
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _controller = MobileScannerController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Device ID')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_done) return;
          final value = capture.barcodes.firstOrNull?.rawValue;
          if (value == null || value.isEmpty) return;
          _done = true;
          Navigator.pop(context, value.trim());
        },
      ),
    );
  }
}
