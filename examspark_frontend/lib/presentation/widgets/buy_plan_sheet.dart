import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/data/groups_repository.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Shown instead of letting a join go through when [GroupJoinEligibility]
/// says no — founder-locked Jul 12, 2026 group-join limits (free=0,
/// ₹199=1, ₹499=3, ₹999=6, teacher=unlimited). Also shown when server
/// trigger blocks join; UI never fakes a successful join.
Future<void> showBuyPlanSheet(BuildContext context, GroupJoinEligibility eligibility) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _BuyPlanSheet(eligibility: eligibility),
  );
}

class _BuyPlanSheet extends StatelessWidget {
  final GroupJoinEligibility eligibility;

  const _BuyPlanSheet({required this.eligibility});

  @override
  Widget build(BuildContext context) {
    final isFree = eligibility.maxGroups == 0;
    final theme = Theme.of(context);
    final maxH = MediaQuery.sizeOf(context).height * 0.72;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Material(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.getCardBorder(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.getAccentTint(context),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.workspace_premium_outlined,
                        color: AppTheme.accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      isFree ? 'Upgrade to join Groups' : 'Group limit reached',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFree
                          ? 'Your current plan (${eligibility.planName}) doesn\'t include joining Groups. '
                              'Upgrade to join a teacher\'s Group.'
                          : 'You\'ve joined ${eligibility.currentGroups}/${eligibility.maxGroups} Groups on '
                              'your ${eligibility.planName} plan. Upgrade to join more.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PlanCompareCard(
                      rows: const [
                        ('₹199', '1 Group'),
                        ('₹499', '3 Groups'),
                        ('₹999', '6 Groups'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/subscription');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                          ),
                        ),
                        child: const Text('View Plans'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Not now',
                          style: TextStyle(color: AppTheme.getSecondaryText(context)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCompareCard extends StatelessWidget {
  final List<(String, String)> rows;

  const _PlanCompareCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.getAccentTint(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.check_circle, size: 18, color: AppTheme.accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${rows[i].$1} Plan',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  rows[i].$2,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.getSecondaryText(context),
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
