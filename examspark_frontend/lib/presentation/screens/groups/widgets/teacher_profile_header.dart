import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/models/teacher_profile_model.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/dashboard/widgets/teacher_social_links_row.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';

/// Large teacher header — premium EdTech profile section (own ExamSpark
/// identity: gradient banner + overlapping avatar + real stat row).
/// No cover photo / follower count invented — only real model fields used.
class TeacherProfileHeader extends StatelessWidget {
  final TeacherProfileModel teacher;
  final VoidCallback? onTapCertificates;

  const TeacherProfileHeader({
    super.key,
    required this.teacher,
    this.onTapCertificates,
  });

  // Recognizable "verified" blue — Twitter/Instagram-style checkmark color.
  // Kept as one constant here so the badge is guaranteed blue regardless of
  // theme (light/dark) or accent color changes elsewhere in the app.
  static const Color _verifiedBlue = Color(0xFF1D9BF0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Banner + overlapping avatar (single, clean layer — no
        // duplicate avatar markup) ----
        SizedBox(
          height: 168,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned.fill(
                bottom: 40,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xff5B5FEF),
                        Color(0xff7B61FF),
                        Color(0xff00C6FF),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x335B5FEF),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30,
                        top: -25,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .08),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -20,
                        bottom: -20,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: .05),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Single overlapping avatar — gradient ring + white border.
              Positioned(
                bottom: 0,
                child: Material(
                  elevation: 10,
                  shape: const CircleBorder(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xff5B5FEF),
                          Color(0xff00C6FF),
                          Color(0xff00E5A8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff5B5FEF).withValues(alpha: .40),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: InitialsAvatar(
                        name: teacher.fullName,
                        photoUrl: teacher.photoUrl,
                        size: 92,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ---- Name + verified ----
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                teacher.fullName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (teacher.isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded, size: 19, color: _verifiedBlue),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff5B5FEF), Color(0xff00C6FF)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              teacher.subject,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Study Community',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                  letterSpacing: 0.6,
                  fontSize: 11,
                ),
          ),
        ),
        const SizedBox(height: 16),

        // ---- Info pills (location / qualification) ----
        if (teacher.locationLabel.isNotEmpty || teacher.qualification != null)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (teacher.locationLabel.isNotEmpty)
                _InfoPill(icon: Icons.location_on_outlined, label: teacher.locationLabel),
              if (teacher.qualification != null)
                _InfoPill(icon: Icons.school_outlined, label: teacher.qualification!),
            ],
          ),

        if (teacher.bio != null && teacher.bio!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            teacher.bio!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                  height: 1.45,
                ),
          ),
        ],
        if (teacher.hasSocialLinks) ...[
          const SizedBox(height: 16),
          TeacherSocialLinksRow(profile: teacher),
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
        gradient: LinearGradient(
          colors: [
            const Color(0xff5B5FEF).withValues(alpha: .10),
            const Color(0xff00C6FF).withValues(alpha: .08),
          ],
        ),
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