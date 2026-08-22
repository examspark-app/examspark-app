import 'package:flutter/material.dart';

class AiModelSelector extends StatelessWidget {
  const AiModelSelector({
    super.key,
    required this.selectedModel,
    required this.onSelected,
  });

  final String selectedModel;
  final ValueChanged<String> onSelected;

  static const models = <({String value, String label})>[
    (value: 'qwen3', label: 'Qwen3'),
    (value: 'gemini', label: 'Gemini Flash'),
    (value: 'claude', label: 'Claude Premium'),
  ];

  static String labelFor(String model) {
    for (final option in models) {
      if (option.value == model) return option.label;
    }
    return 'Qwen3';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'AI Model',
      initialValue: selectedModel,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final model in models)
          PopupMenuItem(value: model.value, child: Text(model.label)),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.deepPurple, size: 18),
            const SizedBox(width: 4),
            Text(
              labelFor(selectedModel),
              style: const TextStyle(
                color: Colors.deepPurple,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, color: Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}
