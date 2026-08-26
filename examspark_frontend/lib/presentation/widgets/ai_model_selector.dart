import 'package:flutter/material.dart';

class AiModelSelector extends StatelessWidget {
  const AiModelSelector({
    super.key,
    required this.selectedModel,
    required this.onSelected,
  });

  final String selectedModel;
  final ValueChanged<String> onSelected;

  static const models = <({String value, String label, IconData icon})>[
    (value: 'qwen3', label: 'Qwen3', icon: Icons.bolt_rounded),
    (value: 'gemini', label: 'Gemini Flash', icon: Icons.auto_awesome_rounded),
    (value: 'claude', label: 'Claude Premium', icon: Icons.workspace_premium_rounded),
  ];

  static String labelFor(String model) {
    for (final option in models) {
      if (option.value == model) return option.label;
    }
    return 'Qwen3';
  }

  static IconData _iconFor(String model) {
    for (final option in models) {
      if (option.value == model) return option.icon;
    }
    return Icons.bolt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final fg = isDark ? Colors.white : const Color(0xFF111111);
    final border = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFDDDDDD);
    final selectedBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
    final muted = isDark ? Colors.white60 : Colors.black54;

    return PopupMenuButton<String>(
      tooltip: 'Select AI Model',
      initialValue: selectedModel,
      onSelected: onSelected,
      offset: const Offset(0, -340),
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: bg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border, width: 0.8),
      ),
      itemBuilder: (context) => [
        for (final model in models)
          PopupMenuItem<String>(
            value: model.value,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: model.value == selectedModel
                    ? selectedBg
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    model.icon,
                    size: 15,
                    color: model.value == selectedModel ? fg : muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    model.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: model.value == selectedModel
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: model.value == selectedModel ? fg : muted,
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (model.value == selectedModel)
                    Icon(Icons.check_rounded, color: fg, size: 16),
                ],
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border, width: 0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(selectedModel), color: muted, size: 14.5),
            const SizedBox(width: 5),
            Text(
              labelFor(selectedModel),
              style: TextStyle(
                color: fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: muted,
            ),
          ],
        ),
      ),
    );
  }
}
