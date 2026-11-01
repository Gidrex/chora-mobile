import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../domain/notes_filter.dart';
import '../../ui/theme_helpers.dart';
import '../../ui/widgets.dart';
import 'note_controller.dart';
import 'widgets/note_blocks.dart';
import 'widgets/notes_message.dart';

/// One note: preview with tappable tasks, raw markdown edit mode.
class NoteViewerScreen extends StatefulWidget {
  const NoteViewerScreen({super.key, required this.file});

  final NoteFileDto file;

  @override
  State<NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<NoteViewerScreen> {
  late final NoteController _note;
  final _editor = TextEditingController();

  /// Text the edit started from; null while previewing.
  String? _base;

  bool get _editing => _base != null;
  bool get _dirty => _editing && _editor.text != _base;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _note = NoteController(
      services.notes,
      services.session.revision,
      widget.file.relPath,
    )..addListener(_onNote);
    _editor.addListener(() => setState(() {}));
    unawaited(_note.load());
  }

  @override
  void dispose() {
    _note.dispose();
    _editor.dispose();
    super.dispose();
  }

  void _onNote() {
    final notice = _note.notice;
    if (notice == null || !mounted) return;
    _note.notice = null;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
  }

  void _startEdit() => setState(() {
    _base = _note.text;
    _editor.text = _note.text ?? '';
  });

  Future<bool> _save() async {
    final base = _base;
    if (base == null) return true;
    final ok = await _note.save(_editor.text, base: base);
    if (!mounted) return ok;
    // On a sync conflict the note reloaded: the next save overwrites it.
    setState(() => _base = ok ? null : (_note.text ?? base));
    return ok;
  }

  /// Ask about unsaved edits; true when it is fine to leave edit mode.
  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return switch (await confirmUnsavedEdits(context)) {
      DiscardChoice.save => await _save(),
      DiscardChoice.discard => true,
      null => false,
    };
  }

  Future<void> _onPop(bool didPop) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    if (!await _confirmLeave() || !mounted) return;
    setState(() => _base = null);
    navigator.pop();
  }

  Future<void> _preview() async {
    if (await _confirmLeave() && mounted) setState(() => _base = null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _note,
      builder: (context, _) => PopScope(
        canPop: !_dirty,
        onPopInvokedWithResult: (didPop, _) => unawaited(_onPop(didPop)),
        child: Scaffold(
          appBar: AppBar(
            title: Text(noteTitle(widget.file)),
            actions: _actions(),
          ),
          body: _body(),
        ),
      ),
    );
  }

  List<Widget> _actions() => [
    if (_editing)
      IconButton(
        icon: const Icon(Icons.check),
        tooltip: 'Save',
        onPressed: _note.saving || !_dirty ? null : () => unawaited(_save()),
      ),
    IconButton(
      icon: Icon(_editing ? Icons.visibility_outlined : Icons.edit_outlined),
      tooltip: _editing ? 'Preview' : 'Edit',
      onPressed: _note.text == null
          ? null
          : _editing
          ? () => unawaited(_preview())
          : _startEdit,
    ),
  ];

  Widget _body() {
    final text = _note.text;
    if (text == null) {
      return _note.error == null
          ? const Center(child: CircularProgressIndicator())
          : NotesMessage(
              icon: Icons.error_outline,
              text: _note.error!,
              action: 'Retry',
              onAction: () => unawaited(_note.load()),
            );
    }
    if (!_editing) {
      return NoteBlocks(
        text: text,
        onToggle: (line) => unawaited(_note.toggle(line)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _editor,
        maxLines: null,
        expands: true,
        autofocus: true,
        textAlignVertical: TextAlignVertical.top,
        style: mono(context, size: 14),
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
    );
  }
}
