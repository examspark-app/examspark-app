import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/group_channel_row.dart';

/// One row in the group channel feed — lecture, notes, quiz, announcement.
/// Flat list style (not chat bubbles). Tap opens content; no reply UI.
class PinnedContentTile extends StatelessWidget {
  final GroupSharedItem item;
  final VoidCallback? onTap;
  /// Teacher-only: pin / unpin (sticky top). Null for students.
  final VoidCallback? onTogglePin;

  const PinnedContentTile({
    super.key,
    required this.item,
    this.onTap,
    this.onTogglePin,
  });

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
    final secondary = AppTheme.getSecondaryText(context);
    final dateLabel = GroupChannelRow.formatActivityDate(item.sharedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.getCardBorder(context)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.isPinned
                      ? AppTheme.getAccentTint(context)
                      : AppTheme.getCardBackground(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: item.isPinned
                        ? AppTheme.accentColor.withValues(alpha: 0.35)
                        : AppTheme.getCardBorder(context),
                  ),
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
                                  fontWeight: item.isPinned
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: item.isPinned
                                    ? AppTheme.accentColor
                                    : secondary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.isPinned ? 'Pinned · $_typeLabel' : _typeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: secondary,
                          ),
                    ),
                    if ((item.body ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: secondary,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTogglePin != null)
                IconButton(
                  tooltip: item.isPinned ? 'Unpin' : 'Pin to top',
                  onPressed: onTogglePin,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 20,
                    color: item.isPinned
                        ? AppTheme.accentColor
                        : secondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
