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

  bool get _hasCertificateBadge =>
      teacher.showCertificatesOnProfile && teacher.certificates.isNotEmpty;

  bool get _hasAboutContent =>
      teacher.experienceYears > 0 ||
      teacher.classLevelsList.isNotEmpty ||
      teacher.examsList.isNotEmpty ||
      teacher.languagesList.isNotEmpty;

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

        // ---- Info pills (location / qualification / certificates) ----
        if (teacher.locationLabel.isNotEmpty ||
            teacher.qualification != null ||
            _hasCertificateBadge)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (teacher.locationLabel.isNotEmpty)
                _InfoPill(icon: Icons.location_on_outlined, label: teacher.locationLabel),
              if (teacher.qualification != null)
                _InfoPill(icon: Icons.school_outlined, label: teacher.qualification!),
              if (_hasCertificateBadge)
                _InfoPill(
                  icon: Icons.workspace_premium_rounded,
                  label: '${teacher.certificates.length} Certificates',
                  onTap: onTapCertificates,
                ),
            ],
          ),

        if (_hasAboutContent) ...[
          const SizedBox(height: 20),
          _AboutSection(teacher: teacher),
        ],

        if (teacher.hasSocialLinks) ...[
          const SizedBox(height: 16),
          TeacherSocialLinksRow(profile: teacher),
        ],
      ],
    );
  }
}

/// "About" card — everything the teacher filled in during profile creation
/// that helps a student decide (experience, classes, boards, language).
/// Each row only renders when that field has data — no empty gaps.
class _AboutSection extends StatelessWidget {
  final TeacherProfileModel teacher;

  const _AboutSection({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (teacher.experienceYears > 0) {
      rows.add(
        _AboutRow(
          icon: Icons.work_history_outlined,
          label: 'Experience',
          child: Text(
            '${teacher.experienceYears}+ years',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      );
    }

    if (teacher.classLevelsList.isNotEmpty) {
      rows.add(
        _AboutRow(
          icon: Icons.class_outlined,
          label: 'Classes',
          child: _ChipWrap(values: teacher.classLevelsList),
        ),
      );
    }

    if (teacher.examsList.isNotEmpty) {
      rows.add(
        _AboutRow(
          icon: Icons.emoji_events_outlined,
          label: 'Boards / Exams',
          child: _ChipWrap(values: teacher.examsList),
        ),
      );
    }

    if (teacher.languagesList.isNotEmpty) {
      rows.add(
        _AboutRow(
          icon: Icons.translate_outlined,
          label: 'Teaches in',
          child: _ChipWrap(values: teacher.languagesList),
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABOUT',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;

  const _AboutRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.getSecondaryText(context)),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _ChipWrap extends StatelessWidget {
  final List<String> values;

  const _ChipWrap({required this.values});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.getAccentTint(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              v,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentColor,
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _InfoPill({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pill = Container(
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
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: pill,
    );
  }
}