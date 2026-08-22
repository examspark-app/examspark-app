import 'package:flutter/material.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_teaching_history_screen.dart';

class EnglishPracticeDrawer extends StatelessWidget {
  const EnglishPracticeDrawer({
    super.key,
    this.nativeLanguage = '',
    this.targetLanguage = 'English',
    this.onChangeLanguage,
    this.onNewChat,
  });

  final String nativeLanguage;
  final String targetLanguage;
  final VoidCallback? onChangeLanguage;
  final VoidCallback? onNewChat;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'English Practice',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: const Text('Current Language'),
              subtitle: Text(
                nativeLanguage.isEmpty
                    ? 'Not selected'
                    : '$targetLanguage · $nativeLanguage',
              ),
              onTap: () {
                Navigator.pop(context);
                onChangeLanguage?.call();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: const Text('New Chat'),
              onTap: () {
                Navigator.pop(context);
                onNewChat?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('History'),
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
              leading: const Icon(Icons.close_rounded),
              title: const Text('Close'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
