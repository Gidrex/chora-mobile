import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/services.dart';
import '../../data/models.dart';
import '../../domain/notes_filter.dart';
import '../lock/unlock.dart';
import 'note_viewer_screen.dart';
import 'notes_controller.dart';
import 'widgets/notes_message.dart';
import 'widgets/project_tree.dart';
import 'widgets/visibility_sheet.dart';

/// Notes as a tree per project, search, visibility and gated open.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late final AppServices _services = AppScope.of(context);
  late final NotesController _controller = NotesController(
    _services.notes,
    _services.settings,
    _services.session.revision,
  );
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_controller.reload());
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      if (!await _services.session.refreshIfChanged()) {
        await _controller.reload();
      }
    } on AppFailure catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _open(NoteFileDto file) async {
    final ok = await unlock(
      context,
      file.security,
      reason: 'Open ${noteTitle(file)}',
    );
    if (!ok || !mounted) return;
    // Unfocus the field itself: that clears the route's focus history, so
    // popping back does not refocus search and reopen the keyboard.
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => NoteViewerScreen(file: file)),
    );
  }

  void _clearSearch() {
    _search.clear();
    _controller.setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'Visible projects',
            onPressed: () => showVisibilitySheet(
              context,
              _services.settings,
              _controller.projectNames,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchField(controller: _search, onChanged: _controller.setQuery),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([_controller, _services.lock]),
              builder: (context, _) => _body(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final c = _controller;
    final trees = c.trees;
    if (c.error != null) {
      return NotesMessage(
        icon: Icons.error_outline,
        text: c.error!,
        action: 'Retry',
        onAction: () => unawaited(c.reload()),
      );
    }
    if (trees.isEmpty) {
      if (c.loading) return const Center(child: CircularProgressIndicator());
      return c.query.trim().isEmpty
          ? NotesMessage(
              icon: Icons.note_add_outlined,
              text: 'No notes yet. Captured and synced notes show up here.',
              action: 'Check for changes',
              onAction: () => unawaited(_refresh()),
            )
          : NotesMessage(
              icon: Icons.search_off,
              text: 'No notes match "${c.query.trim()}".',
              action: 'Clear search',
              onAction: _clearSearch,
            );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          for (final rows in trees)
            ProjectTree(
              rows: rows,
              isLocked: _services.lock.locked,
              onToggle: c.toggle,
              onOpen: _open,
            ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SearchBar(
        controller: controller,
        hintText: 'Search notes',
        leading: const Icon(Icons.search),
        elevation: const WidgetStatePropertyAll(0),
        onChanged: onChanged,
      ),
    );
  }
}
