import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Reusable row for the Profile screen — Subscription, Credits, Storage,
/// Library Size, Settings, Help, Teacher Dashboard, Logout all use this
/// same shape for a consistent, minimal list.
class ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailingText;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const ProfileRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailingText,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.getAccentTint(context),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconColor ?? AppTheme.accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.getSecondaryText(context),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: AppTheme.getSecondaryText(context)),
          ],
        ),
      ),
    );
  }
}
