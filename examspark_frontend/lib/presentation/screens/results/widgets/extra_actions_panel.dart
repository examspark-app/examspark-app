import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';

/// Action panel wired via callbacks to NotesResultScreen / LectureService.
class ExtraActionsPanel extends StatelessWidget {
  final Future<void> Function(String action)? onAction;
  final bool isLoading;

  const ExtraActionsPanel({
    super.key,
    this.onAction,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate More',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.quiz_outlined,
                  label: 'MCQ',
                  cost: CreditCosts.mcqGeneration,
                  onTap: isLoading ? null : () => onAction?.call('mcq'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.assignment_outlined,
                  label: 'Revision',
                  cost: CreditCosts.revisionGeneration,
                  onTap: isLoading ? null : () => onAction?.call('revision_sheet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.help_outline,
                  label: 'Important Qs',
                  cost: CreditCosts.importantQuestionsGeneration,
                  onTap: isLoading ? null : () => onAction?.call('important_questions'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'Answer Key',
                  cost: CreditCosts.answerKeyGeneration,
                  onTap: isLoading ? null : () => onAction?.call('answer_key'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.style_outlined,
                  label: 'Flashcards',
                  cost: CreditCosts.flashcardGeneration,
                  onTap: isLoading ? null : () => onAction?.call('flashcards'),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              icon: Icons.chat_bubble_outline,
              label: 'Ask with RAG',
              cost: CreditCosts.ragQuery,
              onTap: isLoading ? null : () => onAction?.call('rag'),
              isFullWidth: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int cost;
  final VoidCallback? onTap;
  final bool isFullWidth;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.cost,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 14,
          horizontal: isFullWidth ? 16 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$cost',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
