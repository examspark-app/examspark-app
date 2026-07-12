import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';
import 'package:examspark_frontend/presentation/widgets/app_top_bar.dart';

/// Progress tab — placeholder study stats. Real analytics (study time,
/// quiz scores, streaks) connect once quiz/flashcard results are stored
/// server-side (Phase 4/5).
class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppTopBar(title: 'Progress'),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.local_fire_department_outlined, label: 'Study Streak', value: '3 days')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(icon: Icons.schedule_outlined, label: 'Study Time', value: '2h 15m')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.menu_book_outlined, label: 'Lectures Studied', value: '5')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(icon: Icons.quiz_outlined, label: 'Avg Quiz Score', value: '78%')),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'RECENT ACTIVITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: AppTheme.getSecondaryText(context),
            ),
          ),
          const SizedBox(height: 12),
          _ActivityTile(icon: Icons.quiz_outlined, title: 'Completed Physics Quiz', subtitle: 'Score: 16/20 · Yesterday'),
          _ActivityTile(icon: Icons.style_outlined, title: 'Reviewed 12 Flashcards', subtitle: 'Chemistry · 2 days ago'),
          _ActivityTile(icon: Icons.mic_outlined, title: 'Recorded new lecture', subtitle: 'Biology · 3 days ago'),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Full progress tracking connects in a later phase.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.getCardBackground(context),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: AppTheme.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accentColor, size: 22),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ActivityTile({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.getCardBackground(context),
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          border: Border.all(color: AppTheme.getCardBorder(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: AppTheme.getAccentTint(context), borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: Icon(icon, color: AppTheme.accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
