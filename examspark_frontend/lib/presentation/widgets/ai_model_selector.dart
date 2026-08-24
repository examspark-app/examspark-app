import 'package:flutter/material.dart';

class AiModelSelector extends StatelessWidget {
  const AiModelSelector({
    super.key,
    required this.selectedModel,
    required this.onSelected,
  });

  final String selectedModel;
  final ValueChanged<String> onSelected;

  static const _neutral = Color(0xFF5F5F5F);

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
                        ? Colors.black
                        : _neutral.withOpacity(.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    model.icon,
                    size: 18,
                    color: model.value == selectedModel
                        ? Colors.white
                        : _neutral,
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
                  const Icon(Icons.check_rounded, color: Colors.black, size: 18),
              ],
            ),
          ),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          gradient: const LinearGradient(
            colors: [Color(0xFFF7F7F7), Color(0xFFEDEDED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD0D0D0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(selectedModel), color: _neutral, size: 17),
            const SizedBox(width: 6),
            Text(
              labelFor(selectedModel),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Colors.black, size: 20),
          ],
        ),
      ),
    );
  }
}