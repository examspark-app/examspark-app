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

  const GroupCard({
    super.key,
    required this.group,
    required this.onTap,
    required this.onJoinToggle,
    this.isUpdating = false,
  });

  @override
  Widget build(BuildContext context) {
    final teacher = group.teacher;

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
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${teacher.fullName} · ${teacher.subject}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.getSecondaryText(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: group.isJoined
                  ? OutlinedButton(
                      onPressed: isUpdating ? null : onJoinToggle,
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36)),
                      child: isUpdating ? _spinner() : const Text('Joined'),
                    )
                  : ElevatedButton(
                      onPressed: isUpdating ? null : onJoinToggle,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(36)),
                      child: isUpdating ? _spinner() : const Text('Join Group'),
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
