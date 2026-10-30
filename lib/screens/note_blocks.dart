import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Note preview: markdown with natively tappable checkbox rows.
class NoteBlocks extends StatelessWidget {
  const NoteBlocks({super.key, required this.text, required this.onToggle});

  final String text;

  /// Toggle the checkbox at raw line [lineIndex] (currently [checked]).
  final void Function(int lineIndex, bool checked) onToggle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _blocks(context),
    );
  }

  List<Widget> _blocks(BuildContext context) {
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
            onTap: () => onToggle(i, checked),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: checked,
                  onChanged: (_) => onToggle(i, checked),
                ),
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
