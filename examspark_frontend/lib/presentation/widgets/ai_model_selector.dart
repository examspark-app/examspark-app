import 'package:flutter/material.dart';

/// Configurable model option — supports free vs premium distinction.
class AiModelOption {
  final String value;
  final String label;
  final IconData icon;
  final bool isPremium;
  final String? premiumBadge;

  const AiModelOption({
    required this.value,
    required this.label,
    required this.icon,
    this.isPremium = false,
    this.premiumBadge,
  });
}

class AiModelSelector extends StatelessWidget {
  const AiModelSelector({
    super.key,
    required this.selectedModel,
    required this.onSelected,
    this.customModels,
    this.onPremiumTap,
    this.isPremiumUnlocked = false,
  });

  final String selectedModel;
  final ValueChanged<String> onSelected;

  /// Override default model list per feature.
  final List<AiModelOption>? customModels;

  /// Called when user taps a premium model without a paid plan — show upgrade sheet.
  final VoidCallback? onPremiumTap;

  /// When true, user has a paid plan — premium models work directly (no popup).
  final bool isPremiumUnlocked;

  // --- Default model list (Study AI Chat) ---
  static const _defaultModels = <AiModelOption>[
    AiModelOption(
      value: 'chatgpt',
      label: 'GPT-4o-mini',
      icon: Icons.bolt_rounded,
    ),
    AiModelOption(
      value: 'qwen3',
      label: 'Qwen3',
      icon: Icons.speed_rounded,
    ),
    AiModelOption(
      value: 'gemini',
      label: 'Gemini Flash',
      icon: Icons.auto_awesome_rounded,
    ),
    AiModelOption(
      value: 'claude',
      label: 'Claude 3.5 Haiku',
      icon: Icons.workspace_premium_rounded,
      isPremium: true,
      premiumBadge: '🔒 ₹199',
    ),
  ];

  // --- GlowGuide models ---
  static const glowGuideModels = <AiModelOption>[
    AiModelOption(
      value: 'gemini',
      label: 'Gemini Flash',
      icon: Icons.auto_awesome_rounded,
    ),
    AiModelOption(
      value: 'gemini_pro',
      label: 'Gemini Pro',
      icon: Icons.auto_awesome_rounded,
      isPremium: true,
      premiumBadge: '🔒 ₹199',
    ),
    AiModelOption(
      value: 'claude',
      label: 'Claude 3.5 Haiku',
      icon: Icons.workspace_premium_rounded,
      isPremium: true,
      premiumBadge: '🔒 ₹199',
    ),
  ];

  // --- Vision models ---
  static const visionModels = <AiModelOption>[
    AiModelOption(
      value: 'gemini',
      label: 'Gemini Flash',
      icon: Icons.auto_awesome_rounded,
    ),
    AiModelOption(
      value: 'chatgpt',
      label: 'GPT-4o-mini',
      icon: Icons.bolt_rounded,
      isPremium: true,
      premiumBadge: '🔒 ₹199',
    ),
    AiModelOption(
      value: 'claude',
      label: 'Claude 3.5 Haiku',
      icon: Icons.workspace_premium_rounded,
      isPremium: true,
      premiumBadge: '🔒 ₹199',
    ),
  ];

  List<AiModelOption> get _models => customModels ?? _defaultModels;

  static const models = <({String value, String label, IconData icon})>[
    (value: 'chatgpt', label: 'GPT-4o-mini', icon: Icons.bolt_rounded),
    (value: 'qwen3', label: 'Qwen3', icon: Icons.speed_rounded),
    (value: 'gemini', label: 'Gemini Flash', icon: Icons.auto_awesome_rounded),
    (value: 'claude', label: 'Claude 3.5 Haiku', icon: Icons.workspace_premium_rounded),
  ];

  static String labelFor(String model) {
    for (final option in _defaultModels) {
      if (option.value == model) return option.label;
    }
    return 'GPT-4o-mini';
  }

  static IconData _iconFor(String model) {
    for (final option in _defaultModels) {
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
    final currentModels = _models;

    return PopupMenuButton<String>(
      tooltip: 'Select AI Model',
      initialValue: selectedModel,
      onSelected: (value) {
        final option = currentModels.firstWhere(
          (m) => m.value == value,
          orElse: () => currentModels.first,
        );
        // Premium model: if user has no paid plan → show upgrade popup.
        // If user has paid plan (isPremiumUnlocked=true) → allow directly.
        if (option.isPremium && !isPremiumUnlocked && onPremiumTap != null) {
          onPremiumTap!();
          return;
        }
        onSelected(value);
      },
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
        for (final model in currentModels)
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
                  if (model.premiumBadge != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        model.premiumBadge!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
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
