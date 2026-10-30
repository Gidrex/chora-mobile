// Pure text helpers for Capture autocomplete (no Flutter, no I/O).
// Widget state (controllers, focus, panel visibility) stays in the screen.

/// Marker auto-inserted after Enter on a checklist line, else null.
String? continuedMarker(String line) {
  final match = RegExp(r'^(\s*)- \[[ xX]\] ').firstMatch(line);
  if (match == null) return null;
  return '${match.group(1)}- [ ] ';
}

/// Active `@`-file or `#`-header token before [cursor], or null when the
/// suggestions panel must stay hidden. `#` completes headers only after a
/// file was picked ([hashEnabled]).
String? activeToken(String text, int cursor, {required bool hashEnabled}) {
  if (cursor <= 0 || cursor > text.length) return null;
  final before = text.substring(0, cursor);
  final match = RegExp(r'([@#])([\w\-./]*)$').firstMatch(before);
  if (match == null) return null;
  if (match.group(1) == '#' && !hashEnabled) return null;
  return match.group(0);
}

/// Replace the active token before [cursor] with [replacement].
/// Returns the new text and the cursor offset after the replacement.
({String text, int offset}) replaceToken(
  String text,
  int cursor,
  String replacement,
) {
  final before = text.substring(0, cursor);
  final match = RegExp(r'([@#])([\w\-./]*)$').firstMatch(before);
  if (match == null) return (text: text, offset: cursor);
  final next =
      before.substring(0, match.start) + replacement + text.substring(cursor);
  return (text: next, offset: match.start + replacement.length);
}

/// If [text] grew by one trailing newline since [prevText], continue a
/// checklist line with `- [ ] `. Returns the extended text or null.
String? continueChecklist(String text, String prevText) {
  if (text.length == prevText.length + 1 && text.endsWith('\n')) {
    final marker = continuedMarker(prevText.split('\n').last);
    if (marker != null) return '$text$marker';
  }
  return null;
}

/// Insert [snippet] over `[start, end)`; cursor lands after it.
({String text, int offset}) insertSnippet(
  String text,
  int start,
  int end,
  String snippet,
) {
  final next = text.replaceRange(start, end, snippet);
  return (text: next, offset: start + snippet.length);
}

/// Insert `- [ ] ` at the start of the line containing [cursor].
({String text, int offset}) insertCheckboxLine(String text, int cursor) {
  final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
  final next = text.replaceRange(lineStart, lineStart, '- [ ] ');
  return (text: next, offset: cursor + 6);
}
