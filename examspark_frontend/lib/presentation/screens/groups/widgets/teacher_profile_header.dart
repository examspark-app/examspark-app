import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/groups/widgets/verified_badge.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';

/// Large teacher header for the top of the Group Info screen — photo,
/// name, subject, verification, qualification, experience, certificate
/// previews, and a short introduction (bio).
///
/// Inspired by WhatsApp Group Info's top section, but styled with
/// ExamSpark's own premium/minimal design language.
class TeacherProfileHeader extends StatelessWidget {
  final TeacherProfileModel teacher;
  final VoidCallback? onTapCertificates;

  const TeacherProfileHeader({
    super.key,
    required this.teacher,
    this.onTapCertificates,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InitialsAvatar(name: teacher.fullName, photoUrl: teacher.photoUrl, size: 92),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                teacher.fullName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (teacher.isVerified) ...[
              const SizedBox(width: 6),
              const VerifiedBadge(size: 18),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          teacher.subject,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.accentColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (teacher.qualification != null)
              _InfoPill(icon: Icons.school_outlined, label: teacher.qualification!),
            if (teacher.experienceYears > 0)
              _InfoPill(icon: Icons.work_outline, label: '${teacher.experienceYears} yrs experience'),
          ],
        ),
        if (teacher.bio != null && teacher.bio!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            teacher.bio!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.getSecondaryText(context),
            ),
          ),
        ],
        if (teacher.certificates.isNotEmpty) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onTapCertificates,
            child: SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: teacher.certificates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return Container(
                    width: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.getAccentTint(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.getCardBorder(context)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_outlined, color: AppTheme.accentColor, size: 20),
                        const SizedBox(height: 2),
                        Text('Proof', style: TextStyle(fontSize: 9, color: AppTheme.accentColor)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.getSecondaryText(context)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
