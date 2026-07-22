import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

class WorkspaceActionItem {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  const WorkspaceActionItem({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.active = false,
  });
}

/// Compact contextual action row (Copy, Export, Search, Shuffle, Bookmark).
class WorkspaceActionBar extends StatelessWidget {
  final List<WorkspaceActionItem> actions;

  const WorkspaceActionBar({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final a in actions)
          IconButton(
            tooltip: a.tooltip,
            onPressed: a.onPressed,
            icon: Icon(
              a.icon,
              size: 20,
              color: a.active
                  ? AppTheme.accentColor
                  : AppTheme.getSecondaryText(context),
            ),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
      ],
    );
  }
}

Future<void> copyStudyText(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Copied to clipboard')),
  );
}

/// Export = copy for now (no PDF / no new API). Same UX label as Copy for web.
Future<void> exportStudyText(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Exported — text copied to clipboard')),
  );
}
