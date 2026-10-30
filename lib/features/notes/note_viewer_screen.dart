import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/models.dart';
import '../../screens/note_blocks.dart';
import '../../ui/theme_helpers.dart';
import '../../ui/widgets.dart';
import 'notes_controller.dart';

/// Markdown preview with tappable checkboxes + raw edit mode.
class NoteViewerScreen extends StatefulWidget {
  const NoteViewerScreen({super.key, required this.file});

  final NoteFileDto file;

  @override
  State<NoteViewerScreen> createState() => _NoteViewerScreenState();
}

class _NoteViewerScreenState extends State<NoteViewerScreen> {
  NotesController? _controller;
  late final TextEditingController _editor;
  bool _editing = false;

  NotesController get _c => _controller!;

  @override
  void initState() {
    super.initState();
    _editor = TextEditingController();
    _editor.addListener(_touch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      _controller = NotesController(
        AppScope.notesOf(context),
        AppScope.of(context),
      )..addListener(_refresh);
      unawaited(_controller!.open(widget.file));
    }
  }

  @override
  void dispose() {
    _editor.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _touch() {
    if (mounted) setState(() {});
  }

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

  /// Edits the user would lose by leaving.
  bool get _dirty =>
      _editing && _c.fileText != null && _editor.text != _c.fileText;

  Future<void> _save() async {
    if (await _c.saveFile(_editor.text) && mounted) {
      setState(() => _editing = false);
    }
  }

  Future<void> _toggle(int index) async {
    await _c.toggleLine(index);
    if (mounted) setState(() => _editor.text = _c.fileText ?? _editor.text);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null ||
        (controller.fileText == null && controller.fileError == null)) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_dirty) return;
        final navigator = Navigator.of(context);
        final choice = await confirmUnsavedEdits(context);
        if (!mounted) return;
        if (choice == DiscardChoice.save) {
          await _save();
          if (mounted && !_dirty) navigator.pop();
        } else if (choice == DiscardChoice.discard) {
          setState(() => _editor.text = controller.fileText ?? '');
          if (mounted) navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.file.fileName, style: mono(context, size: 15)),
          actions: [
            securityBadge(context, widget.file.security.name),
            IconButton(
              icon: Icon(_editing ? Icons.visibility : Icons.edit),
              tooltip: _editing ? 'Preview' : 'Edit',
              onPressed: controller.fileText == null
                  ? null
                  : () => setState(() {
                      if (!_editing) {
                        _editor.text = controller.fileText ?? '';
                      }
                      _editing = !_editing;
                    }),
            ),
            if (_editing)
              IconButton(
                icon: const Icon(Icons.save),
                tooltip: 'Save',
                onPressed: _save,
              ),
          ],
        ),
        body: controller.fileError != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not open note'),
                    const SizedBox(height: 8),
                    Text(controller.fileError!),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => unawaited(controller.open(widget.file)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _editing
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _editor,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: mono(context, size: 13),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
              )
            : NoteBlocks(
                text: controller.fileText!,
                onToggle: (i, _) => _toggle(i),
              ),
      ),
    );
  }
}
