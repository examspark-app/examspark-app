import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// One row in the "Recent Shared Content" list — lecture, homework,
/// pinned notes, pinned quiz, or pinned announcement.
class PinnedContentTile extends StatelessWidget {
  final GroupSharedItem item;
  final VoidCallback? onTap;

  const PinnedContentTile({super.key, required this.item, this.onTap});

  IconData get _icon {
    switch (item.type) {
      case GroupSharedItemType.lecture:
        return Icons.play_circle_outline;
      case GroupSharedItemType.homework:
        return Icons.assignment_outlined;
      case GroupSharedItemType.notes:
        return Icons.description_outlined;
      case GroupSharedItemType.quiz:
        return Icons.quiz_outlined;
      case GroupSharedItemType.announcement:
        return Icons.campaign_outlined;
    }
  }

  String get _typeLabel {
    switch (item.type) {
      case GroupSharedItemType.lecture:
        return 'Lecture';
      case GroupSharedItemType.homework:
        return 'Homework';
      case GroupSharedItemType.notes:
        return 'Notes';
      case GroupSharedItemType.quiz:
        return 'Quiz';
      case GroupSharedItemType.announcement:
        return 'Announcement';
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppTheme.getCardBorder(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.getAccentTint(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, size: 18, color: AppTheme.accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (item.isPinned) ...[
                        Icon(Icons.push_pin, size: 12, color: AppTheme.accentColor),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _typeLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.getSecondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.getSecondaryText(context)),
          ],
        ),
      ),
    );
  }
}
