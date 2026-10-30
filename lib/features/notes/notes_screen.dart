import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app_state.dart';
import '../../auth.dart';
import '../../data/models.dart';
import 'note_viewer_screen.dart';
import 'notes_controller.dart';
import 'widgets/project_tile.dart';
import 'widgets/visibility_sheet.dart';

/// Projects accordion with filter, visibility settings and gated file open.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  final _expanded = <String>{};
  final _filter = TextEditingController();
  NotesController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      _controller = NotesController(AppScope.notesOf(context), widget.state)
        ..addListener(_refresh);
      unawaited(_controller!.reload());
      widget.state.addListener(_refresh);
      _filter.addListener(_onFilter);
    }
  }

  @override
  void dispose() {
    _filter.dispose();
    widget.state.removeListener(_refresh);
    _controller?.dispose();
    super.dispose();
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

  void _onFilter() => _controller?.setFilter(_filter.text);

  /// Refresh project list (called when the page becomes visible).
  Future<void> reload() => _controller?.reload() ?? Future.value();

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final visible = controller.visibleProjects;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Visibility',
            onPressed: () =>
                showVisibilitySheet(context, widget.state, controller.allDirs),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _filter,
              decoration: const InputDecoration(
                hintText: 'Filter files / projects',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? Center(
                    child: Text(
                      _filter.text.isEmpty ? 'No notes yet' : 'No matches',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: reload,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        for (final p in visible)
                          ProjectTile(
                            project: p,
                            expanded: _expanded.contains(p.dir),
                            onToggle: () => setState(
                              () => _expanded.contains(p.dir)
                                  ? _expanded.remove(p.dir)
                                  : _expanded.add(p.dir),
                            ),
                            onOpenFile: _openFile,
                          ),
                        if (controller.allDirs.any(
                          widget.state.hiddenProjects.contains,
                        ))
                          Center(
                            child: TextButton(
                              onPressed: controller.toggleHidden,
                              child: Text(
                                controller.showHidden
                                    ? 'Hide hidden'
                                    : 'Show hidden',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(NoteFileDto f) async {
    // Session unlock is keyed by path so Capture shares it.
    if (widget.state.needsGate(f.security.name) &&
        widget.state.fileUnlocked[f.relPath] != true) {
      final ok = await unlock(
        context,
        widget.state,
        reason: 'Open ${f.relPath}',
      );
      if (!ok || !context.mounted) return;
      widget.state.fileUnlocked[f.relPath] = true;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => NoteViewerScreen(file: f)),
    );
  }
}
