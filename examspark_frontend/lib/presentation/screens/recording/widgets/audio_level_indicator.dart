import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Placeholder microphone / audio level indicator.
class AudioLevelIndicator extends StatelessWidget {
  const AudioLevelIndicator({
    super.key,
    this.levels = const [0.3, 0.55, 0.75, 0.45, 0.6, 0.35, 0.5],
  });

  /// Normalized bar heights between 0.0 and 1.0.
  final List<double> levels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mic_none_rounded,
            size: 20,
            color: AppTheme.accentColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final level in levels)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        height: 8 + (level * 20),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.35 + level * 0.45),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Mic ready',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
