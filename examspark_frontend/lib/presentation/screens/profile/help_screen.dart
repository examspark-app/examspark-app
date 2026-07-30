import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';

/// Profile → Help (Phase 2 careful slice 1) — static FAQ, no support chat backend.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = <(String, String)>[
    (
      'How do I get notes from a lecture?',
      'Home → Record or upload audio / YouTube / PDF. When processing finishes, open Study Workspace from the chat card or Library.'
    ),
    (
      'What are credits?',
      'Credits power AI actions (Ask, Quiz, Flashcards, …). Your balance is on Profile → Credits. Plans add monthly credits.'
    ),
    (
      'Can I recover a deleted account?',
      'Yes — for 30 days. Profile (or Settings) → last row Delete account; log in and tap Recover before the deadline.'
    ),
    (
      'How do groups work?',
      'Teachers share content. Students join with a code/link, read the feed, take quizzes, and Ask AI — no student chat spam.'
    ),
    (
      'I’m a teacher — where do I start?',
      'Sign up as Teacher → complete profile → Get Verified → Teacher plan → Create Group. Share from Teacher Dashboard → My Library.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Help'),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          Text(
            'FAQ',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Quick answers. Live chat support comes later.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final faq in _faqs) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.getCardBackground(context),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                border: Border.all(color: AppTheme.getCardBorder(context)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  title: Text(
                    faq.$1,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        faq.$2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Need more help? Email support will be listed here when support inbox is ready.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
