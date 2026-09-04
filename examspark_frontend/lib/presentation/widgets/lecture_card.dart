import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/theme/subject_theme_helper.dart';

/// Generic reusable card for a lecture / note item — used in Library and
/// Group "recent shared content" lists. Same visual language everywhere
/// so one lecture always looks the same no matter where it's shown.
class LectureCard extends StatelessWidget {
  final String title;
  final String? subject;
  final String dateLabel;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;
  final bool isFavorite;
  /// When set, shows a star control (does not trigger [onTap]).
  final ValueChanged<bool>? onFavoriteChanged;

  const LectureCard({
    super.key,
    required this.title,
    this.subject,
    required this.dateLabel,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.isFavorite = false,
    this.onFavoriteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolved = SubjectThemeHelper.getSubjectIconAndColor(subject, context);
    final effectiveIcon = icon ?? resolved.$1;
    final effectiveColor = iconColor ?? resolved.$2;
    final bgTint = effectiveColor.withValues(alpha: isDark ? 0.18 : 0.12);

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
                color: bgTint,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(effectiveIcon, color: effectiveColor, size: 20),
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
            if (onFavoriteChanged != null)
              IconButton(
                tooltip: isFavorite ? 'Remove favorite' : 'Add favorite',
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFavorite
                      ? AppTheme.accentColor
                      : AppTheme.getSecondaryText(context),
                ),
                onPressed: () => onFavoriteChanged!(!isFavorite),
              )
            else
              Icon(Icons.chevron_right, color: AppTheme.getSecondaryText(context)),
          ],
        ),
      ),
    );
  }
}
