import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Generic reusable card for a lecture / note item — used in Library and
/// Group "recent shared content" lists. Same visual language everywhere
/// so one lecture always looks the same no matter where it's shown.
class LectureCard extends StatelessWidget {
  final String title;
  final String? subject;
  final String dateLabel;
  final VoidCallback onTap;
  final IconData icon;

  const LectureCard({
    super.key,
    required this.title,
    this.subject,
    required this.dateLabel,
    required this.onTap,
    this.icon = Icons.description_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppTheme.getCardBorder(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.getAccentTint(context),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppTheme.accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [if (subject != null && subject!.isNotEmpty) subject, dateLabel]
                        .whereType<String>()
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.getSecondaryText(context)),
          ],
        ),
      ),
    );
  }
}
