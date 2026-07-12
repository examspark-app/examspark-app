import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// "Sign up to continue" — shown to anonymous [GuestHomeScreen] visitors
/// once they've used their one free Ask AI question (PRODUCT_VISION.md
/// Core User Flow #1: "Anonymous try → One Ask AI → Sign up → @username +
/// Library").
Future<void> showSignupPromptSheet(
  BuildContext context, {
  required VoidCallback onCreateAccount,
  required VoidCallback onSignIn,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SignupPromptSheet(onCreateAccount: onCreateAccount, onSignIn: onSignIn),
  );
}

class _SignupPromptSheet extends StatelessWidget {
  const _SignupPromptSheet({required this.onCreateAccount, required this.onSignIn});

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.getCardBorder(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppTheme.getAccentTint(context), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.auto_awesome, color: AppTheme.accentColor, size: 30),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign up to keep chatting',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ve used your free question. Create a free account to keep asking, '
              'record lectures, and save your notes.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onCreateAccount();
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: const Text('Create Free Account'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onSignIn();
              },
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    );
  }
}
