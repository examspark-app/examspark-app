import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Reusable credits balance pill — shown on Home top bar + Profile screen.
/// Per credit economy rule: users see Credits only, never rupee amounts.
class CreditsPill extends StatelessWidget {
  final int balance;
  final VoidCallback? onTap;

  const CreditsPill({
    super.key,
    required this.balance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.getAccentTint(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accentColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: 15, color: AppTheme.accentColor),
            const SizedBox(width: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                '$balance',
                key: ValueKey<int>(balance),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
