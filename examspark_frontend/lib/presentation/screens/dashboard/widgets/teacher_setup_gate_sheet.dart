import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/services/teacher_setup_gate.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Full-height sheet when Create Group is locked — no skip / Not now.
Future<void> showTeacherSetupGateSheet({
  required BuildContext context,
  required TeacherSetupGateStatus status,
  required VoidCallback onCompleteProfile,
  required VoidCallback onBuyPlan,
  required VoidCallback onGetVerified,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.7,
        maxChildSize: 0.98,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.getCardBackground(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.getSecondaryText(context)
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Complete setup to create a Group',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lock order (no skip):\n'
                  '1) Full profile\n'
                  '2) Get Verified (AI Trusted badge) → unlocks payment\n'
                  '3) Teacher plan ₹2,999 → unlocks Create Group\n\n'
                  'Profile PDF/photo = optional (students), not the gate.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                        height: 1.35,
                      ),
                ),
                if (!status.profileGateComplete) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE57373)),
                    ),
                    child: Text(
                      'Profile pending — red alert. Finish profile before Get Verified.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFB71C1C),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Still needed',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                for (final line in status.missingLabels)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.radio_button_unchecked,
                          size: 18,
                          color: status.profileGateComplete
                              ? AppTheme.getSecondaryText(context)
                              : const Color(0xFFE57373),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                if (!status.profileGateComplete)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onCompleteProfile();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC62828),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Complete full profile'),
                    ),
                  )
                else if (!status.hasVerified)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onGetVerified();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Get Verified (AI)'),
                    ),
                  )
                else if (!status.hasTeacherPlan)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onBuyPlan();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Buy Teacher plan (₹2,999)'),
                    ),
                  ),
                const SizedBox(height: 10),
                if (status.profileGateComplete)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onCompleteProfile();
                    },
                    child: const Text('Edit profile'),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}
