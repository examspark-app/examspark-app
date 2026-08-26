import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/brand/app_brand.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/core/theme/responsive.dart';
import 'package:examspark_frontend/presentation/widgets/brand_mark.dart';
import 'package:examspark_frontend/presentation/widgets/credits_pill.dart';
import 'package:examspark_frontend/presentation/widgets/initials_avatar.dart';

/// Shared top bar reused across Home / Library / Groups / Progress tabs.
/// Per UX rule: Home top bar = Logo · Search · Credits · Notification · Profile.
/// Teacher-only: Home may also show Teacher Dashboard (school icon) in trailing.
/// Other tabs reuse the same visual language with a title instead of the logo.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showLogo;
  final int creditsBalance;
  final String userName;
  final String? userPhotoUrl;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationTap;
  /// Unread in-app notifications — red badge / number on the bell.
  final int notificationUnreadCount;
  final VoidCallback? onCreditsTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onNewChatTap;
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
    this.notificationUnreadCount = 0,
    this.onCreditsTap,
    this.onProfileTap,
    this.onNewChatTap,
    this.trailing,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final barHeight = isMobile ? 52.0 : 56.0;

    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 16, topPad + 2, isMobile ? 8 : 16, 2),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: SafeArea(
        bottom: false,
        top: false,
        child: SizedBox(
          height: barHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                SizedBox(
                  width: 40,
                  height: 40,
                  child: leading!,
                ),
                const SizedBox(width: 2),
              ],
              if (showLogo) ...[
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.40,
                      ),
                      child: BrandMark(
                        tileSize: isMobile ? 28 : 32,
                        fontSize: isMobile ? 15.5 : 17,
                      ),
                    ),
                  ),
                ),
              ] else if (title != null)
                Expanded(
                  child: Text(
                    title!,
                    style: AppBrand.wordmarkStyle(context, fontSize: isMobile ? 15.5 : 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (showLogo || title == null) const Spacer(flex: 1),
              if (onSearchTap != null)
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: onSearchTap,
                  tooltip: 'Search',
                ),
              if (onCreditsTap != null || creditsBalance > 0) ...[
                CreditsPill(balance: creditsBalance, onTap: onCreditsTap),
                const SizedBox(width: 8),
              ],
              ...?trailing,
              if (trailing != null && trailing!.isNotEmpty) const SizedBox(width: 6),
              if (onNotificationTap != null)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: IconButton(
                    tooltip: 'Notifications',
                    onPressed: onNotificationTap,
                    icon: Badge(
                      isLabelVisible: notificationUnreadCount > 0,
                      backgroundColor: Colors.redAccent,
                      label: Text(
                        notificationUnreadCount > 99
                            ? '99+'
                            : '$notificationUnreadCount',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      child: Icon(
                        notificationUnreadCount > 0
                            ? Icons.notifications_rounded
                            : Icons.notifications_none_rounded,
                      ),
                    ),
                  ),
                ),
              if (onProfileTap != null)
                InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: InitialsAvatar(
                      name: userName,
                      photoUrl: userPhotoUrl,
                      size: 34,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
