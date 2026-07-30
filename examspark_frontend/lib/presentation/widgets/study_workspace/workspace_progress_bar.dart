import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Visual progress for flashcards / quiz (replaces percentage text).
class WorkspaceProgressBar extends StatelessWidget {
  final int current; // 1-based
  final int total;
  final String label; // e.g. "Card" or "Question"
  final String? remainingSuffix; // e.g. "cards remaining"

  const WorkspaceProgressBar({
    super.key,
    required this.current,
    required this.total,
    this.label = 'Item',
    this.remainingSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = total <= 0 ? 1 : total;
    final safeCurrent = current.clamp(1, safeTotal);
    final progress = safeCurrent / safeTotal;
    final remaining = (safeTotal - safeCurrent).clamp(0, safeTotal);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$label $safeCurrent of $safeTotal',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Spacer(),
            if (remainingSuffix != null)
              Text(
                remaining == 0
                    ? 'Last $label'.toLowerCase()
                    : '$remaining $remainingSuffix',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppTheme.getCardBorder(context),
            color: AppTheme.accentColor,
          ),
        ),
      ],
    );
  }
}
