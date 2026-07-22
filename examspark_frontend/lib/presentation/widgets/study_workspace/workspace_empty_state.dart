import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Premium empty / error state for Study Workspace tabs.
class WorkspaceEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> reasons;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool primaryLoading;
  final bool primaryElevated;

  const WorkspaceEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.reasons = const [],
    this.primaryLabel,
    this.onPrimary,
    this.primaryLoading = false,
    this.primaryElevated = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.getAccentTint(context),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppTheme.accentColor, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Possible reasons:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            for (final r in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $r',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                      ),
                ),
              ),
          ],
          if (primaryLabel != null && onPrimary != null) ...[
            const SizedBox(height: 20),
            if (primaryElevated)
              ElevatedButton.icon(
                onPressed: primaryLoading ? null : onPrimary,
                icon: primaryLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(primaryLoading ? 'Working…' : primaryLabel!),
              )
            else
              OutlinedButton.icon(
                onPressed: primaryLoading ? null : onPrimary,
                icon: primaryLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(primaryLoading ? 'Working…' : primaryLabel!),
              ),
          ],
        ],
      ),
    );
  }
}
