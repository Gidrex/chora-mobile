/// Markdown task lines, numbered exactly like the Rust backend toggles them:
/// 0-based over `text.split('\n')`; after leading whitespace a task starts
/// with `-`, `*` or `+`, then ` [`, a mark (` `, `x`, `X`) and `]`. Lines
/// inside ``` or ~~~ fences (and the fence lines) are never tasks.
library;

/// One piece of a note preview.
sealed class NoteBlock {
  const NoteBlock();
}

/// Plain markdown between task rows.
final class MarkdownChunk extends NoteBlock {
  const MarkdownChunk(this.text);

  final String text;
}

/// A tappable task on raw line [line].
final class TaskRow extends NoteBlock {
  const TaskRow({
    required this.line,
    required this.indent,
    required this.checked,
    required this.label,
  });

  final int line;
  final int indent;
  final bool checked;
  final String label;
}

typedef _Task = ({int indent, bool checked, String label});

_Task? _task(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.length < 5 ||
      !'-*+'.contains(trimmed[0]) ||
      trimmed.substring(1, 3) != ' [' ||
      trimmed[4] != ']' ||
      !' xX'.contains(trimmed[3])) {
    return null;
  }
  return (
    indent: line.length - trimmed.length,
    checked: trimmed[3] != ' ',
    label: trimmed.substring(5).trim(),
  );
}

bool _isFence(String line) {
  final trimmed = line.trimLeft();
  return trimmed.startsWith('```') || trimmed.startsWith('~~~');
}

/// Per raw line: the task on it, or null (fence-aware).
List<_Task?> _tasks(List<String> lines) {
  var inFence = false;
  final out = <_Task?>[];
  for (final line in lines) {
    if (_isFence(line)) inFence = !inFence;
    out.add(inFence || _isFence(line) ? null : _task(line));
  }
  return out;
}

/// Split [text] into markdown chunks and task rows for the preview.
List<NoteBlock> noteBlocks(String text) {
  final lines = text.split('\n');
  final tasks = _tasks(lines);
  final out = <NoteBlock>[];
  final buffer = <String>[];
  void flush() {
    if (buffer.any((l) => l.trim().isNotEmpty)) {
      out.add(MarkdownChunk(buffer.join('\n')));
    }
    buffer.clear();
  }

  for (var i = 0; i < lines.length; i++) {
    final task = tasks[i];
    if (task == null) {
      buffer.add(lines[i]);
      continue;
    }
    flush();
    out.add(
      TaskRow(
        line: i,
        indent: task.indent,
        checked: task.checked,
        label: task.label,
      ),
    );
  }
  flush();
  return out;
}

/// [text] with the task on [line] flipped, or null when it is not a task.
/// Mirrors the backend so the preview can update before the write lands.
String? flipTask(String text, int line) {
  final lines = text.split('\n');
  if (line < 0 || line >= lines.length) return null;
  final task = _tasks(lines)[line];
  if (task == null) return null;
  final raw = lines[line];
  final at = task.indent + 3;
  lines[line] = raw.replaceRange(at, at + 1, task.checked ? ' ' : 'x');
  return lines.join('\n');
}
