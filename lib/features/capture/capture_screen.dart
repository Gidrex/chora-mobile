import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/services.dart';
import '../../data/models.dart';
import '../../domain/capture_text.dart';
import '../../ui/cloud.dart';
import '../lock/unlock.dart';
import 'capture_controller.dart';
import 'widgets/capture_fields.dart';
import 'widgets/event_options.dart';
import 'widgets/mode_selector.dart';
import 'widgets/pickers.dart';
import 'widgets/priority_selector.dart';
import 'widgets/save_button.dart';
import 'widgets/target_chip.dart';

/// Quick capture: a note append, a calendar event or an agent task.
/// The draft lives in [CaptureController]; this state owns text
/// controllers, focus and the active autocomplete token.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _custom = TextEditingController();
  final _bodyFocus = FocusNode();
  late final AppServices _services;
  late final CaptureController _c;
  String? _token;
  String _prevBody = '';

  @override
  void initState() {
    super.initState();
    _services = AppScope.of(context);
    _c = CaptureController(
      notes: _services.notes,
      events: _services.events,
      settings: _services.settings,
      locked: _services.lock.locked,
      revision: _services.session.revision,
      onEventSaved: _services.reminders.afterSave,
    )..addListener(_onChange);
    _services.lock.addListener(_onChange);
    _title.addListener(() => _c.setTitle(_title.text));
    _body.addListener(_onBody);
    unawaited(_c.reload());
  }

  @override
  void dispose() {
    _services.lock.removeListener(_onChange);
    _c.dispose();
    _title.dispose();
    _body.dispose();
    _custom.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    final notice = _c.notice;
    if (notice == null) return;
    _c.notice = null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(notice)));
  }

  void _onBody() {
    final continued = continueChecklist(_body.text, _prevBody);
    if (continued != null) _setBody(continued, continued.length);
    _prevBody = _body.text;
    _c.setBody(_body.text);
    final token = _c.mode == CaptureMode.event
        ? null
        : activeToken(
            _body.text,
            _body.selection.baseOffset,
            hashEnabled: _c.target != null,
          );
    if (token != _token) setState(() => _token = token);
  }

  void _setBody(String text, int offset) => _body.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: offset),
  );

  void _dropToken() {
    final r = replaceToken(_body.text, _body.selection.baseOffset, '');
    _setBody(r.text, r.offset);
    setState(() => _token = null);
  }

  /// Gated notes ask for an unlock first; a denial leaves the draft as is.
  Future<bool> _pickFile(NoteFileDto file) async {
    if (_c.locked(file) &&
        !await unlock(
          context,
          file.security,
          reason: 'Save to ${file.relPath}',
        )) {
      return false;
    }
    _c.pickFile(file);
    return true;
  }

  Future<void> _pickInline(NoteFileDto file) async {
    if (await _pickFile(file)) _dropToken();
  }

  Future<void> _chooseNote() async {
    final file = await pickNote(context, files: _c.files, locked: _c.locked);
    if (file != null) await _pickFile(file);
  }

  Future<void> _chooseSection() async {
    final header = await pickSection(context, headers: _c.headersFor(''));
    if (header != null) _c.pickHeader(header);
  }

  void _insertCheckbox() {
    final cursor = _body.selection.start >= 0
        ? _body.selection.start
        : _body.text.length;
    final r = insertCheckboxLine(_body.text, cursor);
    _setBody(r.text, r.offset);
    _bodyFocus.requestFocus();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _c.eventDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) _c.setEventDate(picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _c.startMin ~/ 60, minute: _c.startMin % 60),
    );
    if (picked != null) _c.setStartMin(picked.hour * 60 + picked.minute);
  }

  Future<void> _save() async {
    if (!await _c.save()) return;
    _title.clear();
    _body.clear();
  }

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text('The text you wrote will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    _title.clear();
    _body.clear();
    _c.clearDraft();
    final nav = Navigator.of(context);
    nav.canPop() ? nav.pop() : await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Offstage in the tab stack: back belongs to the shell, never ask here.
    final guard = _c.dirty && Visibility.of(context);
    return PopScope(
      canPop: !guard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && guard) unawaited(_confirmLeave());
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Capture'),
          actions: [
            SaveButton(saving: _c.saving, onPressed: _c.canSave ? _save : null),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            // Behind the form, on the screen's bottom edge: its lower half is
            // off screen, the upper half shows through the glass nav bar.
            // Hidden while typing: the keyboard would lift it into the form.
            if (MediaQuery.viewInsetsOf(context).bottom == 0)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: CloudArt(height: 130),
              ),
            _form(context),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) => ListView(
    padding: EdgeInsets.fromLTRB(
      16,
      8,
      16,
      32 + MediaQuery.paddingOf(context).bottom,
    ),
    children: [
      ModeSelector(mode: _c.mode, onChanged: _c.setMode),
      const SizedBox(height: 16),
      CaptureFields(
        controller: _c,
        title: _title,
        body: _body,
        bodyFocus: _bodyFocus,
        token: _token,
        onPickFile: _pickInline,
        onPickHeader: (h) {
          _c.pickHeader(h);
          _dropToken();
        },
        onCheckbox: _insertCheckbox,
      ),
      const SizedBox(height: 16),
      ..._modeOptions(),
    ],
  );

  List<Widget> _modeOptions() => switch (_c.mode) {
    CaptureMode.event => [
      EventOptions(
        controller: _c,
        customDuration: _custom,
        onPickDate: _pickDate,
        onPickTime: _pickTime,
      ),
    ],
    CaptureMode.note || CaptureMode.agent => [
      TargetRow(
        target: _c.target,
        header: _c.targetHeader,
        emptyLabel: _c.mode == CaptureMode.note ? 'Inbox' : 'No related note',
        showSection:
            _c.mode == CaptureMode.note &&
            _c.target != null &&
            !_c.locked(_c.target!),
        onPickNote: _chooseNote,
        onPickSection: _chooseSection,
        onClear: _c.clearTarget,
      ),
      if (_c.mode == CaptureMode.agent) ...[
        const SizedBox(height: 16),
        PrioritySelector(priority: _c.priority, onChanged: _c.setPriority),
      ],
    ],
  };
}
