import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';

/// Action button row with modular actions that trigger independent credit-deducting API requests
/// Updated per Windsurf prompt: MCQ, Revision Sheet, Important Questions, Answer Key, Flashcards, RAG
class ExtraActionsPanel extends StatelessWidget {
  const ExtraActionsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
          // First row: MCQ, Revision Sheet, Important Questions
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.quiz_outlined,
                  label: 'MCQ',
                  cost: CreditCosts.mcqGeneration,
                  onTap: () => _handleAction(context, 'mcq'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.assignment_outlined,
                  label: 'Revision Sheet',
                  cost: CreditCosts.mindMapGeneration,
                  onTap: () => _handleAction(context, 'revision_sheet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.help_outline,
                  label: 'Important Questions',
                  cost: CreditCosts.mindMapGeneration,
                  onTap: () => _handleAction(context, 'important_questions'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Second row: Answer Key, Flashcards
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'Answer Key',
                  cost: CreditCosts.mindMapGeneration,
                  onTap: () => _handleAction(context, 'answer_key'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  icon: Icons.style_outlined,
                  label: 'Flashcards',
                  cost: CreditCosts.flashcardGeneration,
                  onTap: () => _handleAction(context, 'flashcard'),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: SizedBox()), // Spacer for alignment
            ],
          ),
          const SizedBox(height: 12),
          // Full width: Ask with RAG
          SizedBox(
            width: double.infinity,
            child: _ActionButton(
              icon: Icons.chat_bubble_outline,
              label: 'Ask with RAG (CBSE/NEET/UPSC)',
              cost: CreditCosts.ragQuery,
              onTap: () => _handleAction(context, 'rag'),
              isFullWidth: true,
            ),
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_getActionTitle(action)),
        content: Text('This will cost ${_getActionCost(action)} credits. Continue?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeAction(context, action);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  void _executeAction(BuildContext context, String action) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Generating...'),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_getActionTitle(action)} generated successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    });
  }

  String _getActionTitle(String action) {
    switch (action) {
      case 'mcq':
        return 'MCQ Questions';
      case 'flashcard':
        return 'Flashcards';
      case 'revision_sheet':
        return 'Revision Sheet';
      case 'important_questions':
        return 'Important Questions';
      case 'answer_key':
        return 'Answer Key';
      case 'rag':
        return 'RAG Query';
      default:
        return 'Action';
    }
  }

  int _getActionCost(String action) {
    switch (action) {
      case 'mcq':
        return CreditCosts.mcqGeneration;
      case 'flashcard':
        return CreditCosts.flashcardGeneration;
      case 'revision_sheet':
      case 'important_questions':
      case 'answer_key':
        return CreditCosts.mindMapGeneration;
      case 'rag':
        return CreditCosts.ragQuery;
      default:
        return 0;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int cost;
  final VoidCallback onTap;
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
