import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/widgets/teacher_social_links_row.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/verified_badge.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';

/// Teacher's own public profile card — shown at the top of the Teacher
/// Dashboard. Tap "Edit" to open TeacherProfileEditSheet.
class TeacherProfileCard extends StatelessWidget {
  final TeacherProfileModel profile;
  final VoidCallback onEdit;
  final VoidCallback? onEditSocialLinks;
  final VoidCallback? onGetVerified;

  const TeacherProfileCard({
    super.key,
    required this.profile,
    required this.onEdit,
    this.onEditSocialLinks,
    this.onGetVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: profile.fullName, photoUrl: profile.photoUrl, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.fullName,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 6),
                          const VerifiedBadge(size: 16),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.subject,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.accentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (profile.locationLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.locationLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.getSecondaryText(context),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (profile.qualification != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.qualification!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.getSecondaryText(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Profile',
                onPressed: onEdit,
              ),
            ],
          ),
          if (profile.hasSocialLinks) ...[
            const SizedBox(height: 12),
            TeacherSocialLinksRow(profile: profile, compact: true),
          ],
          if (onEditSocialLinks != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEditSocialLinks,
                icon: const Icon(Icons.link, size: 18),
                label: Text(
                  profile.hasSocialLinks
                      ? 'Edit social links'
                      : 'Social links (optional)',
                ),
              ),
            ),
          ],
          if (onGetVerified != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onGetVerified,
                icon: Icon(
                  profile.isVerified
                      ? Icons.verified_outlined
                      : Icons.shield_outlined,
                  size: 18,
                ),
                label: Text(
                  profile.isVerified
                      ? 'Trusted · Get Verified again (AI)'
                      : 'Get Verified (AI) — unlocks Teacher plan',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentColor,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 1, color: AppTheme.getCardBorder(context)),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatBlock(label: 'Students', value: '${profile.totalStudents}'),
              _StatBlock(label: 'Groups', value: '${profile.totalGroups}'),
              _StatBlock(label: 'Lectures', value: '${profile.totalSharedLectures}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;

  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.getSecondaryText(context), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
