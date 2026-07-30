import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/teacher_setup_gate.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Checklist — lock: profile → AI Get Verified → Teacher plan → Create Group.
class TeacherSetupChecklistCard extends StatelessWidget {
  final TeacherSetupGateStatus status;
  final VoidCallback onEditProfile;
  final VoidCallback onBuyPlan;
  final VoidCallback? onGetVerified;
  final VoidCallback? onCreateGroup;

  const TeacherSetupChecklistCard({
    super.key,
    required this.status,
    required this.onEditProfile,
    required this.onBuyPlan,
    this.onGetVerified,
    this.onCreateGroup,
  });

  @override
  Widget build(BuildContext context) {
    if (status.canCreateGroup) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.getAccentTint(context),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppTheme.getCardBorder(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Setup complete — you can Create Group.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (onCreateGroup != null)
              TextButton(
                onPressed: onCreateGroup,
                child: const Text('Create'),
              ),
          ],
        ),
      );
    }

    final profileDone = status.profileGateComplete;
    final items = <(String, bool)>[
      ('1. Full profile', profileDone),
      ('2. Get Verified (AI)', status.hasVerified),
      ('3. Teacher plan ₹2,999', status.hasTeacherPlan),
      ('Full Name', status.hasFullName),
      ('Teaching Subject (1+)', status.hasSubject),
      ('City', status.hasCity),
      ('State', status.hasState),
      ('Qualification', status.hasQualification),
      (
        'Certificate on profile (optional — for students)',
        status.hasCertificate,
      ),
    ];

    final borderColor = profileDone
        ? AppTheme.getCardBorder(context)
        : const Color(0xFFE57373);
    final bg = profileDone
        ? AppTheme.getCardBackground(context)
        : const Color(0xFFFFEBEE);

    String nextHint;
    if (!profileDone) {
      nextHint =
          'Complete full profile first. Get Verified, payment & Create Group stay locked.';
    } else if (!status.hasVerified) {
      nextHint =
          'Next: Get Verified (AI) → then Buy Teacher plan → then Create Group. '
          '${status.checklistDone}/${TeacherSetupGateStatus.checklistTotal}';
    } else if (!status.hasTeacherPlan) {
      nextHint =
          'Next: Buy Teacher plan ₹2,999 → then Create Group. '
          '${status.checklistDone}/${TeacherSetupGateStatus.checklistTotal}';
    } else {
      nextHint =
          'Almost done. ${status.checklistDone}/${TeacherSetupGateStatus.checklistTotal}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: borderColor, width: profileDone ? 1 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                profileDone ? Icons.checklist : Icons.warning_amber_rounded,
                color: profileDone ? AppTheme.accentColor : const Color(0xFFC62828),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  profileDone ? 'Teacher setup' : 'Profile pending — RED alert',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: profileDone ? null : const Color(0xFFB71C1C),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            nextHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: profileDone
                      ? AppTheme.getSecondaryText(context)
                      : const Color(0xFFC62828),
                ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    item.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: item.$2
                        ? AppTheme.accentColor
                        : (profileDone
                            ? AppTheme.getSecondaryText(context)
                            : const Color(0xFFE57373)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.$1,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: item.$1.startsWith('1.') ||
                                    item.$1.startsWith('2.') ||
                                    item.$1.startsWith('3.')
                                ? FontWeight.w600
                                : null,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !profileDone
                  ? onEditProfile
                  : (!status.hasVerified && onGetVerified != null)
                      ? onGetVerified
                      : status.canBuyTeacherPlan
                          ? onBuyPlan
                          : onEditProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: !profileDone
                    ? const Color(0xFFC62828)
                    : AppTheme.accentColor,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                !profileDone
                    ? 'Complete full profile now'
                    : !status.hasVerified
                        ? 'Get Verified (AI)'
                        : !status.hasTeacherPlan
                            ? 'Buy Teacher plan'
                            : 'Edit profile',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      status.canGetVerified && onGetVerified != null
                          ? onGetVerified
                          : null,
                  child: const Text('Get Verified'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: status.canBuyTeacherPlan ? onBuyPlan : null,
                  child: const Text('Buy plan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
