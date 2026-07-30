/// Shareable study chips (generated from recording) — teacher All / specific.
/// Keys align with Study Workspace tabs + Home-style extras when present.
class ShareChipCatalog {
  ShareChipCatalog._();

  static const notes = 'notes';
  static const summary = 'summary';
  static const transcript = 'transcript';
  static const flashcards = 'flashcards';
  static const quiz = 'quiz';
  static const revision = 'revision';
  static const importantQuestions = 'important_questions';
  static const mindMap = 'mind_map';
  static const fiveMinRevision = 'five_min_revision';
  static const visual = 'visual';
  static const learnMore = 'learn_more';
  static const memoryTricks = 'memory_tricks';
  static const commonMistakes = 'common_mistakes';
  static const cheatSheet = 'cheat_sheet';
  static const teacherTips = 'teacher_tips';
  static const examBooster = 'exam_booster';

  static const Map<String, String> labels = {
    notes: 'Notes',
    summary: 'Summary',
    transcript: 'Transcript',
    flashcards: 'Flashcards',
    quiz: 'Quiz',
    revision: 'Revision',
    importantQuestions: 'Important Questions',
    mindMap: 'Mind Map',
    fiveMinRevision: '5 Min Revision',
    visual: 'Diagram / Visual',
    learnMore: 'Learn More',
    memoryTricks: 'Memory',
    commonMistakes: 'Common Mistakes',
    cheatSheet: 'Cheat Sheet',
    teacherTips: 'Teacher Tips',
    examBooster: 'Exam Booster',
  };

  /// Workspace tab index for chips that map to Study Workspace tabs.
  static int? workspaceTabIndex(String chip) {
    switch (chip) {
      case notes:
        return 0;
      case summary:
        return 1;
      case transcript:
        return 2;
      case flashcards:
        return 3;
      case quiz:
        return 4;
      case revision:
        return 5;
      default:
        return null;
    }
  }

  static List<int> workspaceTabIndexes(Iterable<String> chips) {
    final out = <int>{};
    for (final c in chips) {
      final i = workspaceTabIndex(c);
      if (i != null) out.add(i);
    }
    // Always allow at least Notes if somehow empty after filter.
    if (out.isEmpty) out.add(0);
    return out.toList()..sort();
  }

  /// Extra types in `extras` table → share chip keys.
  static const Map<String, String> extrasTypeToChip = {
    'flashcards': flashcards,
    'flashcard': flashcards,
    'quiz': quiz,
    'mcq': quiz,
    'revision': revision,
    'revision_sheet': revision,
    'important_questions': importantQuestions,
    'mind_map': mindMap,
    'five_min_revision': fiveMinRevision,
    'inline_transcript': transcript,
    'learn_more': learnMore,
    'memory_tricks': memoryTricks,
    'common_mistakes': commonMistakes,
    'cheat_sheet': cheatSheet,
    'teacher_tips': teacherTips,
    'exam_booster': examBooster,
    'visual': visual,
  };

  static String? labelFor(String chip) => labels[chip];
}
