import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/teacher_achievement_model.dart';
import 'package:examspark_frontend/core/models/teacher_certificate_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Certificates + Qualification + Awards + Documents — renders nothing at
/// all if the teacher has not uploaded anything (spec rule: "Only if
/// uploaded" — never fabricate credentials).
class TeacherAchievementsSection extends StatelessWidget {
  final List<TeacherCertificateModel> certificates;
  final List<TeacherAchievementModel> achievements;

  const TeacherAchievementsSection({
    super.key,
    required this.certificates,
    required this.achievements,
  });

  IconData _iconFor(TeacherAchievementType type) {
    switch (type) {
      case TeacherAchievementType.qualification:
        return Icons.school_outlined;
      case TeacherAchievementType.award:
        return Icons.emoji_events_outlined;
      case TeacherAchievementType.document:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (certificates.isEmpty && achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEACHER ACHIEVEMENTS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.getSecondaryText(context),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.getCardBackground(context),
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(color: AppTheme.getCardBorder(context)),
          ),
          child: Column(
            children: [
              for (final cert in certificates)
                _AchievementTile(icon: Icons.verified_outlined, title: cert.title, subtitle: 'Certificate'),
              for (final ach in achievements)
                _AchievementTile(icon: _iconFor(ach.type), title: ach.title, subtitle: ach.description),
            ],
          ),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _AchievementTile({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.getAccentTint(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppTheme.accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.getSecondaryText(context)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
