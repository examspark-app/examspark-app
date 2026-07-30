import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/verified_badge.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';

/// WhatsApp-style **channel** row for My Groups — list → open feed.
/// Not a chat bubble row: no message composer, tap opens Group Info / feed.
class GroupChannelRow extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onTap;
  final int unreadCount;
  final String? unreadPreview;

  const GroupChannelRow({
    super.key,
    required this.group,
    required this.onTap,
    this.unreadCount = 0,
    this.unreadPreview,
  });

  DateTime get _lastActivity {
    final items = group.recentSharedItems;
    if (items.isEmpty) return group.createdAt;
    return GroupSharedItem.sortedForFeed(items).first.sharedAt;
  }

  String get _subtitle {
    final preview = (unreadPreview ?? '').trim();
    if (unreadCount > 0 && preview.isNotEmpty) return preview;
    final teacher = group.teacher;
    return '${teacher.fullName} · ${group.studentsCount} students';
  }

  static String formatActivityDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${local.day} ${months[local.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final teacher = group.teacher;
    final hasUnread = unreadCount > 0;
    final secondary = AppTheme.getSecondaryText(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.getCardBorder(context)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                InitialsAvatar(
                  name: teacher.fullName,
                  photoUrl: teacher.photoUrl,
                  size: 48,
                ),
                if (teacher.isVerified)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: const VerifiedBadge(size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 16,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatActivityDate(_lastActivity),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: hasUnread
                                  ? AppTheme.accentColor
                                  : secondary,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: secondary,
                                fontWeight: hasUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
