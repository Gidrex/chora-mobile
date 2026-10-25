import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../app_state.dart';
import '../auth.dart';
import '../backend.dart';
import '../theme.dart';

/// Projects accordion with filter, visibility settings and gated file open.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.state});

  final AppState state;

  @override
  State<NotesScreen> createState() => NotesScreenState();
}

class NotesScreenState extends State<NotesScreen> {
  List<ProjectDto> _projects = [];
  final _expanded = <String>{};
  final _filter = TextEditingController();
  bool _showHidden = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
    reload();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      final projects = await listAllProjects(rootDir: Backend.root);
      if (mounted) setState(() => _projects = projects);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _allDirs =>
      _projects.map((p) => p.dir).where((d) => d != '(files)').toList();

  @override
  Widget build(BuildContext context) {
    final hidden = widget.state.hiddenProjects.toSet();
    final query = _filter.text.toLowerCase();
    final visible = _projects.where((p) {
      if (hidden.contains(p.dir) && !_showHidden) return false;
      if (query.isEmpty) return true;
      return p.dir.toLowerCase().contains(query) ||
          p.files.any((f) => f.relPath.toLowerCase().contains(query));
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Visibility',
            onPressed: () => _visibilitySheet(),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: reload,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        for (final p in visible) _projectCard(p),
                        if (_projects.any(hidden.contains))
                          Center(
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _showHidden = !_showHidden),
                              child: Text(
                                _showHidden ? 'Hide hidden' : 'Show hidden',
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

  Widget _projectCard(ProjectDto p) {
    final open = _expanded.contains(p.dir);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            title: Text(
              p.dir,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: p.about.isEmpty ? null : Text(p.about),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                securityBadge(context, p.security.name),
                Icon(open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            onTap: () => setState(
              () => open ? _expanded.remove(p.dir) : _expanded.add(p.dir),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
              child: Column(
                children: [
                  for (var i = 0; i < p.files.length; i++)
                    _fileRow(p, p.files[i], last: i == p.files.length - 1),
                  if (p.files.isEmpty)
                    const ListTile(dense: true, title: Text('(empty)')),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _fileRow(ProjectDto p, NoteFileDto f, {required bool last}) {
    final depth = f.relPath.split('/').length - 1;
    final label = f.relPath.startsWith('${p.dir}/')
        ? f.relPath.substring(p.dir.length + 1)
        : f.fileName;
    return InkWell(
      onTap: () => _openFile(f),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: depth * 14,
              child: depth == 0
                  ? null
                  : Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
            ),
            Text(last ? '└─ ' : '├─ ', style: mono(context, size: 11)),
            Expanded(child: Text(label, style: mono(context))),
            securityBadge(context, f.security.name),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(NoteFileDto f) async {
    final key = '${f.relPath}@${f.security.name}';
    if (widget.state.needsGate(f.security.name) &&
        !(widget.state.fileUnlocked[key] ?? false)) {
      final ok = await unlock(
        context,
        widget.state,
        reason: 'Open ${f.relPath}',
      );
      if (!ok || !context.mounted) return;
      widget.state.fileUnlocked[key] = true;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteViewer(state: widget.state, file: f),
      ),
    );
    reload();
  }

  Future<void> _visibilitySheet() async {
    final hidden = widget.state.hiddenProjects.toSet();
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Visible projects',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              for (final dir in _allDirs)
                SwitchListTile(
                  title: Text(dir, style: mono(ctx)),
                  value: !hidden.contains(dir),
                  onChanged: (v) async {
                    if (v) {
                      hidden.remove(dir);
                    } else {
                      hidden.add(dir);
                    }
                    await widget.state.setHiddenProjects(hidden.toList());
                    setSheet(() {});
                    setState(() {});
                  },
                ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Hidden projects are excluded from Capture @-autocomplete too.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Markdown preview with tappable checkboxes + raw edit mode.
class NoteViewer extends StatefulWidget {
  const NoteViewer({super.key, required this.state, required this.file});

  final AppState state;
  final NoteFileDto file;

  @override
  State<NoteViewer> createState() => _NoteViewerState();
}

class _NoteViewerState extends State<NoteViewer> {
  String? _text;
  bool _editing = false;
  late final TextEditingController _editor;

  @override
  void initState() {
    super.initState();
    _editor = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final content = await readNoteFile(
        rootDir: Backend.root,
        relPath: widget.file.relPath,
      );
      if (mounted) {
        setState(() {
          _text = content.text;
          _editor.text = content.text;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _save() async {
    try {
      await saveNoteFile(
        rootDir: Backend.root,
        relPath: widget.file.relPath,
        newBody: _editor.text,
      );
      if (mounted) {
        setState(() {
          _text = _editor.text;
          _editing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
    }
  }

  Future<void> _toggle(int lineIndex, bool checked) async {
    try {
      final updated = await toggleMarkdownCheckbox(
        rootDir: Backend.root,
        relPath: widget.file.relPath,
        lineIndex: BigInt.from(lineIndex),
      );
      if (mounted) {
        setState(() {
          _text = updated;
          _editor.text = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(Backend.errMsg(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.fileName, style: mono(context, size: 15)),
        actions: [
          securityBadge(context, widget.file.security.name),
          IconButton(
            icon: Icon(_editing ? Icons.visibility : Icons.edit),
            tooltip: _editing ? 'Preview' : 'Edit',
            onPressed: _text == null
                ? null
                : () => setState(() => _editing = !_editing),
          ),
          if (_editing)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: _text == null
          ? const Center(child: CircularProgressIndicator())
          : _editing
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _editor,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: mono(context, size: 13),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _blocks(_text!),
            ),
    );
  }

  /// Render markdown with natively tappable checkbox rows.
  List<Widget> _blocks(String text) {
    final lines = text.split('\n');
    final out = <Widget>[];
    final buffer = <String>[];
    void flush() {
      if (buffer.isEmpty) return;
      out.add(
        MarkdownBody(
          data: buffer.join('\n'),
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(
            Theme.of(context),
          ).copyWith(codeblockDecoration: null),
        ),
      );
      buffer.clear();
    }

    final checkbox = RegExp(r'^(\s*)-\s\[([ xX])\]\s?(.*)$');
    for (var i = 0; i < lines.length; i++) {
      final match = checkbox.firstMatch(lines[i]);
      if (match == null) {
        buffer.add(lines[i]);
        continue;
      }
      flush();
      final indent = (match.group(1)!.length ~/ 2);
      final checked = match.group(2) != ' ';
      final label = match.group(3)!;
      out.add(
        Padding(
          padding: EdgeInsets.only(left: indent * 20),
          child: InkWell(
            onTap: () => _toggle(i, checked),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(value: checked, onChanged: (_) => _toggle(i, checked)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: MarkdownBody(data: label, selectable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    flush();
    return out;
  }
}
