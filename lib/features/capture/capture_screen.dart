import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../data/settings_store.dart';
import '../../auth.dart';
import '../../data/models.dart';
import '../../domain/capture_text.dart';
import '../../ui/widgets.dart';
import 'capture_controller.dart';
import 'widgets/bento_grid.dart';
import 'widgets/capture_fields.dart';
import 'widgets/event_section.dart';

/// GTD inbox: title + markdown body with `@`/`#` autocomplete, bento
/// switches (delegate / event / priority) and a Save action.
/// Draft and submission live in [CaptureController]; this widget owns only
/// text controllers, focus and the suggestion panel state.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.state, required this.onSaved});

  final SettingsStore state;
  final VoidCallback onSaved;

  @override
  State<CaptureScreen> createState() => CaptureScreenState();
}

class CaptureScreenState extends State<CaptureScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _bodyFocus = FocusNode();
  final _durationManual = TextEditingController(text: '45m');

  CaptureController? _controller;
  String? _token; // active @/# token, null when panel hidden
  String _prevBody = '';

  CaptureController get _c => _controller!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final controller = CaptureController(
        AppScope.captureOf(context),
        widget.state,
      );
      controller
        ..addListener(_refresh)
        ..eventTime = _snapNow();
      unawaited(controller.reload());
      _controller = controller;
      _title.addListener(() => controller.setTitle(_title.text));
      _body.addListener(_trackToken);
      _body.addListener(() => controller.setBody(_body.text));
    }
  }

  static TimeOfDay _snapNow() {
    final now = TimeOfDay.now();
    var mins = now.hour * 60 + now.minute;
    mins = (mins ~/ 15 + 1) * 15 % (24 * 60);
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    _durationManual.dispose();
    _controller?.dispose();
    super.dispose();
  }

  /// Refresh project list (called when the page becomes visible).
  Future<void> refresh() => _controller?.reload() ?? Future.value();

  void _refresh() {
    if (mounted) setState(() {});
    final notice = _controller?.notice;
    if (notice != null) {
      _controller!.consumeNotice();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notice)));
    }
  }

  void _trackToken() {
    // Enter at the end of a checklist line starts the next one with `- [ ] `.
    final continued = continueChecklist(_body.text, _prevBody);
    if (continued != null) {
      _prevBody = continued;
      _body.value = TextEditingValue(
        text: continued,
        selection: TextSelection.collapsed(offset: continued.length),
      );
    }
    _prevBody = _body.text;
    final token = activeToken(
      _body.text,
      _body.selection.baseOffset,
      hashEnabled: _c.targetNote != null,
    );
    if (token != _token && mounted) setState(() => _token = token);
  }

  void _replaceToken(String replacement) {
    final result = replaceToken(
      _body.text,
      _body.selection.baseOffset,
      replacement,
    );
    _body.value = TextEditingValue(
      text: result.text,
      selection: TextSelection.collapsed(offset: result.offset),
    );
  }

  /// Pick an autocomplete file as the capture target.
  /// Gated files ask for unlock first; denial leaves the draft untouched.
  Future<bool> _pickFile(NoteFileDto file) async {
    if (_c.locked(file)) {
      if (!await unlock(
        context,
        widget.state,
        reason: 'Append to ${file.relPath}',
      )) {
        return false;
      }
      widget.state.fileUnlocked[file.relPath] = true;
    }
    _c.pickFile(file);
    setState(() => _token = null);
    _replaceToken('');
    _bodyFocus.requestFocus();
    return true;
  }

  void _pickHeader(String header) {
    _c.pickHeader(header);
    setState(() => _token = null);
    _replaceToken('');
    _bodyFocus.requestFocus();
  }

  void _insertAtCursor(String snippet) {
    final value = _body.value;
    final start = value.selection.start >= 0
        ? value.selection.start
        : value.text.length;
    final end = value.selection.end >= 0
        ? value.selection.end
        : value.text.length;
    final r = insertSnippet(value.text, start, end, snippet);
    _body.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(offset: r.offset),
    );
    _bodyFocus.requestFocus();
  }

  /// `- [ ] ` at the start of the current line.
  void _insertCheckbox() {
    final value = _body.value;
    final cursor = value.selection.start >= 0
        ? value.selection.start
        : value.text.length;
    final r = insertCheckboxLine(value.text, cursor);
    _body.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(offset: r.offset),
    );
    _bodyFocus.requestFocus();
  }

  Future<void> _save() async {
    final path = await _c.save();
    if (!mounted) return;
    if (path != null) {
      _title.clear();
      _body.clear();
      _durationManual.text = '45m';
      widget.onSaved();
    }
  }

  void _clearDraft() {
    _title.clear();
    _body.clear();
    _durationManual.text = '45m';
    _c.clearDraft();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
      },
      child: Focus(
        autofocus: false,
        child: PopScope(
          canPop: !controller.dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || !controller.dirty) return;
            final navigator = Navigator.of(context);
            final choice = await confirmUnsavedEdits(context);
            if (!mounted) return;
            if (choice == DiscardChoice.save) {
              await _save();
              if (mounted && !controller.dirty) navigator.pop();
            } else if (choice == DiscardChoice.discard) {
              _clearDraft();
              if (mounted) navigator.pop();
            }
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Capture'),
              actions: [
                FilledButton(
                  onPressed: controller.saving || !controller.canSave
                      ? null
                      : _save,
                  child: const Text('Save ->'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CaptureFields(
                  controller: controller,
                  title: _title,
                  body: _body,
                  focusNode: _bodyFocus,
                  token: _token,
                  onSubmitted: (_) => _bodyFocus.requestFocus(),
                  onPickHeader: _pickHeader,
                  onPickFile: (f, hit) async {
                    if (await _pickFile(f) && hit.isNotEmpty) {
                      controller.pickHeader(hit);
                    }
                  },
                  onCheckbox: _insertCheckbox,
                  onProject: () => _insertAtCursor('@'),
                  onSection: () => _insertAtCursor('#'),
                ),
                const SizedBox(height: 12),
                BentoGrid(
                  delegate: controller.delegate,
                  asEvent: controller.asEvent,
                  onDelegate: controller.setDelegate,
                  onAsEvent: controller.setAsEvent,
                ),
                const SizedBox(height: 12),
                EventSection(
                  controller: controller,
                  durationManual: _durationManual,
                  onPickDate: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: controller.eventDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) controller.setEventDate(picked);
                  },
                  onDurationSet: (d) {
                    controller.setDuration(d);
                    _durationManual.text = d;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
