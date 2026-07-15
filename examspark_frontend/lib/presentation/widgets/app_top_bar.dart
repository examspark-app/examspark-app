import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/credits_pill.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';

/// Shared top bar reused across Home / Library / Groups / Progress tabs.
/// Per UX rule: Home top bar = Logo · Search · Credits · Notification · Profile.
/// Other tabs reuse the same visual language with a title instead of the logo.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showLogo;
  final int creditsBalance;
  final String userName;
  final String? userPhotoUrl;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onCreditsTap;
  final VoidCallback? onProfileTap;
  final List<Widget>? trailing;
  /// Optional back / close control (e.g. Library folder drill-in).
  final Widget? leading;

  const AppTopBar({
    super.key,
    this.title,
    this.showLogo = false,
    this.creditsBalance = 0,
    this.userName = 'User',
    this.userPhotoUrl,
    this.onSearchTap,
    this.onNotificationTap,
    this.onCreditsTap,
    this.onProfileTap,
    this.trailing,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: AppTheme.getCardBorder(context))),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 4),
              ],
              if (showLogo) ...[
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'E',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'ExamSpark',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ] else if (title != null)
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (showLogo || title == null) const Spacer(),
              if (onSearchTap != null)
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: onSearchTap,
                  tooltip: 'Search',
                ),
              if (onNotificationTap != null)
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded),
                  onPressed: onNotificationTap,
                  tooltip: 'Notifications',
                ),
              if (onCreditsTap != null || creditsBalance > 0) ...[
                CreditsPill(balance: creditsBalance, onTap: onCreditsTap),
                const SizedBox(width: 10),
              ],
              ...?trailing,
              if (onProfileTap != null)
                InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InitialsAvatar(name: userName, photoUrl: userPhotoUrl, size: 34),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
