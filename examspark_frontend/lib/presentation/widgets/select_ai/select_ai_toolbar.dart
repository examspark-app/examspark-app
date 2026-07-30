import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_costs.dart';

/// One Select AI toolbar action.
class SelectAiMenuAction {
  final String id;
  final String label;
  final IconData icon;
  final int credits;

  const SelectAiMenuAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.credits,
  });
}

const kSelectAiMenuActions = <SelectAiMenuAction>[
  SelectAiMenuAction(
    id: 'ask_followup',
    label: 'Ask AI',
    icon: Icons.chat_bubble_outline,
    credits: CreditCosts.selectAiExplain,
  ),
  SelectAiMenuAction(
    id: 'explain',
    label: 'Explain',
    icon: Icons.menu_book_outlined,
    credits: CreditCosts.selectAiExplain,
  ),
  SelectAiMenuAction(
    id: 'simplify',
    label: 'Simplify',
    icon: Icons.auto_awesome,
    credits: CreditCosts.selectAiExplain,
  ),
  SelectAiMenuAction(
    id: 'memory_trick',
    label: 'Memory Trick',
    icon: Icons.psychology_outlined,
    credits: CreditCosts.selectAiExplain,
  ),
  SelectAiMenuAction(
    id: 'exam_view',
    label: 'Exam View',
    icon: Icons.school_outlined,
    credits: CreditCosts.selectAiExplain,
  ),
  SelectAiMenuAction(
    id: 'generate_quiz',
    label: 'Generate Quiz',
    icon: Icons.quiz_outlined,
    credits: CreditCosts.selectAiMiniQuiz,
  ),
  SelectAiMenuAction(
    id: 'generate_flashcards',
    label: 'Generate Flashcards',
    icon: Icons.style_outlined,
    credits: CreditCosts.selectAiMiniFlashcards,
  ),
  SelectAiMenuAction(
    id: 'translate',
    label: 'Translate',
    icon: Icons.translate,
    credits: CreditCosts.selectAiExplain,
  ),
];

/// Bottom sheet listing Select AI actions for the current selection.
Future<String?> showSelectAiActionSheet(
  BuildContext context, {
  required String selectedText,
}) {
  final preview = selectedText.length > 80
      ? '${selectedText.substring(0, 80)}…'
      : selectedText;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select AI',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '"$preview"',
                style: Theme.of(sheetContext).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final action in kSelectAiMenuActions)
                      ListTile(
                        leading: Icon(action.icon, size: 22),
                        title: Text(action.label),
                        trailing: Text(
                          '${action.credits} cr',
                          style: Theme.of(sheetContext).textTheme.bodySmall,
                        ),
                        onTap: () => Navigator.pop(sheetContext, action.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
