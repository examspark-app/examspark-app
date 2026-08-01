import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/group_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/verified_badge.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';

/// Clean, minimal group card — a Study Community item, not a chat list
/// row. Shows only what matters: teacher photo, name, subject, verified
/// badge, qualification, student count, and a Join/Leave button.
class GroupCard extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onTap;
  final VoidCallback onJoinToggle;
  final bool isUpdating;
  /// Unread teacher-post count (WhatsApp-style).
  final int unreadCount;
  /// Latest unread preview line under the group name.
  final String? unreadPreview;

  const GroupCard({
    super.key,
    required this.group,
    required this.onTap,
    required this.onJoinToggle,
    this.isUpdating = false,
    this.unreadCount = 0,
    this.unreadPreview,
  });

  @override
  Widget build(BuildContext context) {
    final teacher = group.teacher;
    final infoChips = group.quickInfoChips;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppTheme.getCardBorder(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    InitialsAvatar(name: teacher.fullName, photoUrl: teacher.photoUrl, size: 52),
                    if (teacher.isVerified)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppTheme.getCardBackground(context),
                            shape: BoxShape.circle,
                          ),
                          child: const VerifiedBadge(size: 16),
                        ),
                      ),
                    if (unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 5),
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
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (unreadCount > 0 &&
                          (unreadPreview ?? '').isNotEmpty) ...[
                        Text(
                          unreadPreview!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.getSecondaryText(context),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        '${teacher.fullName} · ${teacher.subject}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (infoChips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final label in infoChips)
                              _QuickInfoChip(label: label),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (teacher.qualification != null) ...[
                            QualificationChip(label: teacher.qualification!),
                            const SizedBox(width: 8),
                          ],
                          Icon(Icons.people_outline, size: 14, color: AppTheme.getSecondaryText(context)),
                          const SizedBox(width: 4),
                          Text(
                            '${group.studentsCount} students',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.getSecondaryText(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (group.isJoined)
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppTheme.getSecondaryText(context),
                    ),
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'leave') onJoinToggle();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'leave',
                        child: Row(
                          children: [
                            const Icon(Icons.logout, size: 18, color: Color(0xFFB71C1C)),
                            const SizedBox(width: 10),
                            const Text(
                              'Leave group',
                              style: TextStyle(color: Color(0xFFB71C1C)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: group.isJoined
                  ? ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                      ),
                      child: isUpdating ? _spinner() : const Text('Open group'),
                    )
                  : ElevatedButton(
                      onPressed: isUpdating ? null : onJoinToggle,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(36),
                      ),
                      child: isUpdating
                          ? _spinner()
                          : const Text('Join Group'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _spinner() {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// Small pill for a group's quick-glance field (subject / class / board /
/// language) — only rendered for fields the teacher actually filled in.
class _QuickInfoChip extends StatelessWidget {
  final String label;

  const _QuickInfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.getAccentTint(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.accentColor,
        ),
      ),
    );
  }
}