import 'package:flutter/material.dart';
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
    final bg = backgroundColor ?? const Color(0xFF141417);
    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: bg,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF2A2A2E), width: 0.5),
                ),
              ),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'English Practice',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded, color: Colors.white70),
              title: const Text(
                'Current Language',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                nativeLanguage.isEmpty
                    ? 'Not selected'
                    : '$targetLanguage · $nativeLanguage',
                style: const TextStyle(color: Colors.white60),
              ),
              onTap: () {
                Navigator.pop(context);
                onChangeLanguage?.call();
              },
            ),
            const Divider(color: Color(0xFF2A2A2E)),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined, color: Colors.white70),
              title: const Text(
                'New Chat',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                onNewChat?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded, color: Colors.white70),
              title: const Text(
                'History',
                style: TextStyle(color: Colors.white),
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
              leading: const Icon(Icons.close_rounded, color: Colors.white70),
              title: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
