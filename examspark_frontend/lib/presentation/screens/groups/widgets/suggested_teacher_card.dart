import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/suggested_teacher_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/verified_badge.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';

/// Compact horizontal-scroll card used in the "Suggested Teachers" row
/// below the Group Info screen.
class SuggestedTeacherCard extends StatelessWidget {
  final SuggestedTeacherModel teacher;
  final VoidCallback onJoinToggle;
  final bool isUpdating;

  const SuggestedTeacherCard({
    super.key,
    required this.teacher,
    required this.onJoinToggle,
    this.isUpdating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              InitialsAvatar(name: teacher.name, photoUrl: teacher.photoUrl, size: 56),
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
                    child: const VerifiedBadge(size: 15),
                  ),
                ),
              // Match Score Badge on top-left if available
              if (teacher.matchScore != null)
                Positioned(
                  left: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${teacher.matchScore}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            teacher.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            teacher.subject,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.getSecondaryText(context),
              fontSize: 11,
            ),
          ),
          if (teacher.matchesLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              teacher.matchesLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.accentColor,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isUpdating ? null : onJoinToggle,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(30),
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: isUpdating
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(teacher.isJoined ? 'Joined' : 'Join'),
            ),
          ),
        ],
      ),
    );
  }
}