import 'package:flutter/material.dart';

/// Even Material widgets shared by all screens (ref: tmp/widgets.jpg).
/// Radii and spacing follow `.agents/design.md` tokens only:
/// 12 for tiles/inputs, 20 for cards (from `CardTheme`), stadium for pills.
/// No raw colors here: everything comes from the `ColorScheme`.

/// Grouped card with a `titleMedium` header and divided rows.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
      rows.add(children[i]);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...rows,
          ],
        ),
      ),
    );
  }
}

/// Rounded icon tile used as row leading, 40x40 at radius 12.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20),
    );
  }
}

/// Icon tile + title + trailing (chevron by default).
class EvenRow extends StatelessWidget {
  const EvenRow({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconTile(icon: icon),
      title: Text(title),
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}

/// Icon tile + title + switch; tapping the row toggles it.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconTile(icon: icon),
      title: Text(title),
      trailing: Switch(value: value, onChanged: enabled ? onChanged : null),
      onTap: enabled ? () => onChanged(!value) : null,
    );
  }
}

/// Pill button, 48 high. Disabled while [onPressed] is null.
class PillButton extends StatelessWidget {
  const PillButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : primary = true;

  const PillButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : primary = false;

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    const shape = StadiumBorder();
    const minSize = Size(0, 48);
    if (primary) {
      return FilledButton(
        style: FilledButton.styleFrom(minimumSize: minSize, shape: shape),
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: minSize, shape: shape),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// Unsaved-edits guard result for [confirmUnsavedEdits].
enum DiscardChoice { save, discard }

/// "Unsaved changes?" dialog: Save / Discard / Cancel (dismiss = null).
/// Screens wrap their [Scaffold] in a [PopScope] and call this when dirty.
Future<DiscardChoice?> confirmUnsavedEdits(BuildContext context) {
  return showDialog<DiscardChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unsaved changes'),
      content: const Text('Save your edits before leaving?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, DiscardChoice.discard),
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, DiscardChoice.save),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
