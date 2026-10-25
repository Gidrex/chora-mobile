import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../backend.dart';
import '../notifications.dart';
import '../theme.dart';

/// Marker auto-inserted after Enter on a checklist line, else null.
String? continuedMarker(String line) {
  final match = RegExp(r'^(\s*)- \[[ xX]\] ').firstMatch(line);
  if (match == null) return null;
  return '${match.group(1)}- [ ] ';
}

/// GTD inbox: title + markdown body with `@`/`#` autocomplete, bento
/// switches (delegate / event / priority) and a Save action.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.state, required this.onSaved});

  final AppState state;
  final VoidCallback onSaved;

  @override
  State<CaptureScreen> createState() => CaptureScreenState();
}

class CaptureScreenState extends State<CaptureScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _bodyFocus = FocusNode();
  final _durationManual = TextEditingController(text: '45m');

  List<ProjectDto> _projects = [];
  bool _delegate = false;
  bool _asEvent = false;
  Priority _priority = Priority.medium;

  DateTime _eventDate = DateTime.now();
  TimeOfDay _eventTime = TimeOfDay.now();
  String _duration = '45m';

  String? _targetNote;
  String? _targetHeader;
  String? _token; // active @/# token, null when panel hidden
  bool _saving = false;
  String _prevBody = '';

  @override
  void initState() {
    super.initState();
    _eventTime = _snap(TimeOfDay.now(), true);
    _body.addListener(_trackToken);
    _reload();
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    _durationManual.dispose();
    super.dispose();
  }

  /// Refresh project list (called when the page becomes visible).
  Future<void> refresh() => _reload();

  Future<void> _reload() async {
    try {
      final projects = await listAllProjects(rootDir: Backend.root);
      if (mounted) setState(() => _projects = projects);
    } catch (e) {
      if (mounted) _snack(Backend.errMsg(e));
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Visible files minus projects hidden in Notes settings.
  List<NoteFileDto> get _visibleFiles {
    final hidden = widget.state.hiddenProjects.toSet();
    return [
      for (final p in _projects)
        if (!hidden.contains(p.dir)) ...p.files,
    ];
  }

  void _trackToken() {
    // Enter at the end of a checklist line starts the next one with `- [ ] `.
    final text = _body.text;
    if (text.length == _prevBody.length + 1 && text.endsWith('\n')) {
      final marker = continuedMarker(_prevBody.split('\n').last);
      if (marker != null) {
        final next = '$text$marker';
        _prevBody = next;
        _body.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    }
    _prevBody = _body.text;
    final cursor = _body.selection.baseOffset;
    String? token;
    if (cursor > 0 && cursor <= _body.text.length) {
      final before = _body.text.substring(0, cursor);
      final match = RegExp(r'([@#])([\w\-./]*)$').firstMatch(before);
      if (match != null) {
        // `#` completes headers only after a file was picked.
        if (match.group(1) == '#' && _targetNote == null) {
          token = null;
        } else {
          token = match.group(0);
        }
      }
    }
    if (token != _token && mounted) setState(() => _token = token);
  }

  void _replaceToken(String replacement) {
    final cursor = _body.selection.baseOffset;
    final before = _body.text.substring(0, cursor);
    final match = RegExp(r'([@#])([\w\-./]*)$').firstMatch(before);
    if (match == null) return;
    final next =
        before.substring(0, match.start) +
        replacement +
        _body.text.substring(cursor);
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: match.start + replacement.length,
      ),
    );
  }

  void _pickFile(NoteFileDto file) {
    setState(() {
      _targetNote = file.relPath;
      _targetHeader = null;
      _token = null;
    });
    _replaceToken('');
    _bodyFocus.requestFocus();
  }

  void _pickHeader(String header) {
    setState(() {
      _targetHeader = header;
      _token = null;
    });
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
    final next = value.text.replaceRange(start, end, snippet);
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
    _bodyFocus.requestFocus();
  }

  /// `- [ ] ` at the start of the current line.
  void _insertCheckbox() {
    final value = _body.value;
    final cursor = value.selection.start >= 0
        ? value.selection.start
        : value.text.length;
    final lineStart = value.text.lastIndexOf('\n', cursor - 1) + 1;
    final next = value.text.replaceRange(lineStart, lineStart, '- [ ] ');
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: cursor + 6),
    );
    _bodyFocus.requestFocus();
  }

  static TimeOfDay _snap(TimeOfDay t, bool forward) {
    var mins = t.hour * 60 + t.minute;
    mins = forward ? (mins ~/ 15 + 1) * 15 : ((mins - 1) ~/ 15) * 15;
    mins = mins % (24 * 60);
    return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final duration = _durationManual.text.trim().isEmpty
          ? _duration
          : _durationManual.text.trim();
      final path = await submitCapture(
        req: CaptureRequest(
          rootDir: Backend.root,
          title: _title.text,
          body: _body.text,
          targetNotePath: _targetNote,
          targetHeader: _targetHeader,
          delegateToAgent: _delegate,
          createAsEvent: _asEvent,
          eventDateIso: _asEvent ? Backend.isoOf(_eventDate) : null,
          eventTimeHhmm: _asEvent ? _fmtTime(_eventTime) : null,
          eventDuration: _asEvent ? duration : null,
          priority: _priority,
        ),
      );
      if (_asEvent) {
        await Reminders.rescheduleUpcoming(
          enabled: widget.state.notifEnabled,
          minutesBefore: widget.state.notifMinutes,
        );
        await Reminders.maybeAutoAlarm(
          enabled: widget.state.autoAlarm,
          mode: widget.state.alarmMode,
          beforeMin: widget.state.alarmBeforeMin,
          event: EventDto(
            index: BigInt.zero,
            title: _title.text,
            dateIso: Backend.isoOf(_eventDate),
            timeHhmm: _fmtTime(_eventTime),
            durationStr: duration,
            context: _body.text,
            isRepeatable: false,
          ),
        );
      }
      _title.clear();
      _body.clear();
      setState(() {
        _targetNote = null;
        _targetHeader = null;
        _delegate = false;
        _asEvent = false;
      });
      widget.onSaved();
      _snack('Saved → $path');
    } catch (e) {
      _snack(Backend.errMsg(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
      },
      child: Focus(
        autofocus: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Capture'),
            actions: [
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save ->'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'Write your thoughts...',
                  border: InputBorder.none,
                  filled: false,
                ),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _bodyFocus.requestFocus(),
              ),
              const SizedBox(height: 8),
              if (_targetNote != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          '@$_targetNote${_targetHeader == null ? '' : '#$_targetHeader'}',
                          style: mono(context),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() {
                          _targetNote = null;
                          _targetHeader = null;
                        }),
                      ),
                    ],
                  ),
                ),
              if (_token != null) _suggestions(),
              TextField(
                controller: _body,
                focusNode: _bodyFocus,
                maxLines: 8,
                minLines: 4,
                style: mono(context, size: 13.5),
                decoration: const InputDecoration(
                  hintText: 'Markdown, - [ ] checklists, @project, #section',
                ),
              ),
              const SizedBox(height: 8),
              _quickBar(),
              const SizedBox(height: 12),
              _bentoTiles(scheme),
              const SizedBox(height: 12),
              _priorityRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _insertCheckbox,
            icon: const Icon(Icons.check_box_outlined, size: 18),
            label: const Text('Checkbox'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _insertAtCursor('@'),
            icon: const Text('@'),
            label: const Text('Project'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _insertAtCursor('#'),
            icon: const Text('#'),
            label: const Text('Section'),
          ),
        ],
      ),
    );
  }

  Widget _suggestions() {
    final scheme = Theme.of(context).colorScheme;
    final token = _token!;
    final isHeader = token.startsWith('#');
    List<Widget> rows;
    if (isHeader) {
      final file = _visibleFiles.cast<NoteFileDto?>().firstWhere(
        (f) => f?.relPath == _targetNote,
        orElse: () => null,
      );
      final query = token.substring(1).toLowerCase();
      final headers = (file?.headers ?? [])
          .where((h) => h.toLowerCase().contains(query))
          .toList();
      rows = [
        for (final h in headers.take(8))
          ListTile(
            dense: true,
            title: Text('# $h', style: mono(context)),
            onTap: () => _pickHeader(h),
          ),
      ];
      if (rows.isEmpty) {
        rows = [
          const ListTile(dense: true, title: Text('No matching headers')),
        ];
      }
    } else {
      var query = token.substring(1);
      String headerQuery = '';
      final hash = query.indexOf('#');
      if (hash >= 0) {
        headerQuery = query.substring(hash + 1).toLowerCase();
        query = query.substring(0, hash);
      }
      final q = query.toLowerCase();
      final files = _visibleFiles
          .where((f) => f.relPath.toLowerCase().contains(q))
          .toList();
      rows = [
        for (final f in files.take(8))
          ListTile(
            dense: true,
            leading: const Icon(Icons.folder_outlined, size: 18),
            title: Text(f.relPath, style: mono(context)),
            trailing: Text(
              '[${f.security.name}]',
              style: mono(context, size: 11),
            ),
            onTap: () {
              if (hash >= 0 && headerQuery.isNotEmpty) {
                final hit = f.headers.firstWhere(
                  (h) => h.toLowerCase().contains(headerQuery),
                  orElse: () => '',
                );
                _pickFile(f);
                if (hit.isNotEmpty) {
                  setState(() => _targetHeader = hit);
                }
              } else {
                _pickFile(f);
              }
            },
          ),
      ];
      if (rows.isEmpty) {
        rows = [const ListTile(dense: true, title: Text('No matching notes'))];
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border.all(color: scheme.primary, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView(shrinkWrap: true, children: rows),
    );
  }

  Widget _bentoTiles(ColorScheme scheme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.0,
      children: [
        _tile(
          scheme,
          title: 'Delegate to Agent',
          subtitle: '-> to-agent/',
          value: _delegate,
          onChanged: (v) => setState(() => _delegate = v),
        ),
        _tile(
          scheme,
          title: 'Record as Event',
          subtitle: 'events/*.md',
          value: _asEvent,
          onChanged: (v) => setState(() => _asEvent = v),
        ),
      ],
    );
  }

  Widget _tile(
    ColorScheme scheme, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: value ? scheme.primaryContainer : scheme.surfaceContainer,
          border: Border.all(color: scheme.outlineVariant, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Switch(value: value, onChanged: onChanged),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(subtitle, style: mono(context, size: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityRow() {
    if (_asEvent) return _eventPickers();
    return _prioritySegmented();
  }

  Widget _prioritySegmented() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<Priority>(
        segments: const [
          ButtonSegment(value: Priority.low, label: Text('Low')),
          ButtonSegment(value: Priority.medium, label: Text('Med')),
          ButtonSegment(value: Priority.high, label: Text('High')),
          ButtonSegment(value: Priority.urgent, label: Text('! Urgent')),
        ],
        selected: {_priority},
        onSelectionChanged: (s) => setState(() => _priority = s.first),
      ),
    );
  }

  Widget _eventPickers() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(
                () => _eventDate = _eventDate.subtract(const Duration(days: 1)),
              ),
            ),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _eventDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _eventDate = picked);
                },
                child: Text(
                  'Date: ${Backend.isoOf(_eventDate)}',
                  style: mono(context),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(
                () => _eventDate = _eventDate.add(const Duration(days: 1)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: () =>
                  setState(() => _eventTime = _snap(_eventTime, false)),
              child: const Text('-15m'),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Time: ${_fmtTime(_eventTime)}',
                  style: mono(context, size: 14),
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () =>
                  setState(() => _eventTime = _snap(_eventTime, true)),
              child: const Text('+15m'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final d in ['15m', '30m', '45m', '1h', '2h'])
              ChoiceChip(
                label: Text(d, style: mono(context)),
                selected: _duration == d,
                onSelected: (_) => setState(() {
                  _duration = d;
                  _durationManual.text = d;
                }),
              ),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _durationManual,
                style: mono(context),
                decoration: const InputDecoration(
                  labelText: 'Duration',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _prioritySegmented(),
      ],
    );
  }
}
