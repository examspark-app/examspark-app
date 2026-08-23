import 'package:flutter/material.dart';

class AiModelSelector extends StatelessWidget {
  const AiModelSelector({
    super.key,
    required this.selectedModel,
    required this.onSelected,
  });

  final String selectedModel;
  final ValueChanged<String> onSelected;

  static const _violet = Color(0xFF5137ED);

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
    return PopupMenuButton<String>(
      tooltip: 'AI Model',
      initialValue: selectedModel,
      onSelected: onSelected,
      offset: const Offset(0, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      itemBuilder: (context) => [
        for (final model in models)
          PopupMenuItem(
            value: model.value,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: model.value == selectedModel
                        ? _violet
                        : _violet.withOpacity(.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    model.icon,
                    size: 18,
                    color: model.value == selectedModel
                        ? Colors.white
                        : _violet,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    model.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (model.value == selectedModel)
                  const Icon(Icons.check_rounded, color: _violet, size: 18),
              ],
            ),
          ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF6F3FF), Color(0xFFEFE9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8D1FF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(selectedModel), color: _violet, size: 17),
            const SizedBox(width: 6),
            Text(
              labelFor(selectedModel),
              style: const TextStyle(
                color: _violet,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: _violet, size: 20),
          ],
        ),
      ),
    );
  }
}