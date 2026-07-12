import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Shown instead of letting a join go through when [GroupJoinEligibility]
/// says no — founder-locked Jul 12, 2026 group-join limits (free=0,
/// ₹199=1, ₹499=3, ₹999=6, teacher=unlimited). Client-side gate only for
/// now; real server-side enforcement is Phase 5.
Future<void> showBuyPlanSheet(BuildContext context, GroupJoinEligibility eligibility) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _BuyPlanSheet(eligibility: eligibility),
  );
}

class _BuyPlanSheet extends StatelessWidget {
  final GroupJoinEligibility eligibility;

  const _BuyPlanSheet({required this.eligibility});

  @override
  Widget build(BuildContext context) {
    final isFree = eligibility.maxGroups == 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppTheme.getAccentTint(context), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(Icons.workspace_premium_outlined, color: AppTheme.accentColor, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              isFree ? 'Upgrade to join Groups' : 'Group limit reached',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isFree
                  ? 'Your current plan (${eligibility.planName}) doesn\'t include joining Groups. Upgrade to '
                      'join a teacher\'s Group.'
                  : 'You\'ve joined ${eligibility.currentGroups}/${eligibility.maxGroups} Groups on your '
                      '${eligibility.planName} plan. Upgrade to join more.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            _planLimitRow('₹199', '1 Group'),
            _planLimitRow('₹499', '3 Groups'),
            _planLimitRow('₹999', '6 Groups'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/subscription');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
                ),
                child: const Text('View Plans'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planLimitRow(String plan, String limit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: Colors.green[700]),
          const SizedBox(width: 8),
          Text('$plan Plan — $limit'),
        ],
      ),
    );
  }
}
