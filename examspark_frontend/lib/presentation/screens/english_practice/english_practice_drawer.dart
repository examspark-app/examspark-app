import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_teaching_history_screen.dart';

class EnglishPracticeDrawer extends StatelessWidget {
  const EnglishPracticeDrawer({
    super.key,
    this.nativeLanguage = '',
    this.targetLanguage = 'English',
    this.onChangeLanguage,
    this.onNewChat,
    this.backgroundColor,
  });

  final String nativeLanguage;
  final String targetLanguage;
  final VoidCallback? onChangeLanguage;
  final VoidCallback? onNewChat;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? const Color(0xFF141417) : const Color(0xFFF7F5F9));
    final primaryText = AppTheme.getPrimaryText(context);
    final subText = AppTheme.getSecondaryText(context);
    final divider = AppTheme.getCardBorder(context);
    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                  bottom: BorderSide(color: divider, width: 0.5),
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'English Practice',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.language_rounded, color: subText),
              title: Text(
                'Current Language',
                style: TextStyle(color: primaryText),
              ),
              subtitle: Text(
                nativeLanguage.isEmpty
                    ? 'Not selected'
                    : '$targetLanguage · $nativeLanguage',
                style: TextStyle(color: subText),
              ),
              onTap: () {
                Navigator.pop(context);
                onChangeLanguage?.call();
              },
            ),
            Divider(color: divider),
            ListTile(
              leading: Icon(Icons.add_comment_outlined, color: subText),
              title: Text(
                'New Chat',
                style: TextStyle(color: primaryText),
              ),
              onTap: () {
                Navigator.pop(context);
                onNewChat?.call();
              },
            ),
            ListTile(
              leading: Icon(Icons.history_rounded, color: subText),
              title: Text(
                'History',
                style: TextStyle(color: primaryText),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EnglishTeachingHistoryScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.close_rounded, color: subText),
              title: Text(
                'Close',
                style: TextStyle(color: primaryText),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
