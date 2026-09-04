import 'package:flutter/material.dart';

/// Friendly labels / filters for [credit_transactions] rows (UI only).
class CreditHistoryDisplay {
  CreditHistoryDisplay._();

  static const filterAll = 'all';
  static const filterRecordings = 'recordings';
  static const filterStudyTools = 'study_tools';
  static const filterAskAi = 'ask_ai';

  static String normalizeAction(String? action) =>
      (action ?? '').trim().toLowerCase();

  static String featureLabel(String? action, String? description) {
    final a = normalizeAction(action);
    final d = (description ?? '').toLowerCase();
    if (a == 'english_practice' || a.contains('english_practice') || d.contains('english practice')) {
      return 'English Practice';
    }
    if (a == 'glow_guide' || a.contains('glow_guide') || d.contains('glowguide') || d.contains('glow guide')) {
      return 'GlowGuide Care AI';
    }
    switch (a) {
      case 'audio_transcription':
        return 'Record Lecture';
      case 'youtube_link':
        return 'YouTube Notes';
      case 'quiz':
        return 'Quiz Generated';
      case 'flashcards':
        return 'Flashcards';
      case 'revision':
        return 'Revision Notes';
      case 'five_min_revision':
        return '5 Minute Revision';
      case 'important_questions':
        return 'Important Questions';
      case 'mind_map':
        return 'Mind Map';
      case 'ask_ai':
      case 'ask_ai_web':
        return 'Ask AI';
      case 'home_ai_vision':
        return 'Photo Ask';
      case 'select_ai':
        return 'Select AI';
      case 'pdf_analysis':
        return 'PDF Analysis';
      case 'diagram_image':
        return 'Diagram / Image';
      case 'credit_pack':
      case 'subscription_monthly':
      case 'payment_grant':
        return 'Credits Added';
      case 'refund':
        return 'Refund Adjustment';
      default:
        if (a.startsWith('home_ai_tool_regen_')) {
          return 'Study Tool Regenerate';
        }
        if (a.isNotEmpty) {
          return a
              .split('_')
              .where((p) => p.isNotEmpty)
              .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
              .join(' ');
        }
        final dTrim = (description ?? '').trim();
        if (dTrim.isNotEmpty) {
          final first = dTrim.split('\n').first.trim();
          return first.length > 40 ? '${first.substring(0, 37)}…' : first;
        }
        return 'Credit change';
    }
  }

  /// Feature icon and accent color based on action & description for clear visual recognition.
  static (IconData, Color) featureTheme(String? action, String? description, BuildContext context) {
    final a = normalizeAction(action);
    final d = (description ?? '').toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (a == 'english_practice' || a.contains('english_practice') || d.contains('english practice')) {
      return (Icons.record_voice_over_rounded, isDark ? const Color(0xFF26A69A) : const Color(0xFF12A594));
    }
    if (a == 'glow_guide' || a.contains('glow_guide') || d.contains('glowguide') || d.contains('glow guide')) {
      return (Icons.eco_rounded, isDark ? const Color(0xFFFF7043) : const Color(0xFFD85A30));
    }
    if (a == 'ask_ai' || a == 'ask_ai_web' || a.startsWith('home_ai') || d.contains('home ai')) {
      if (a == 'home_ai_vision' || d.contains('vision') || d.contains('photo') || d.contains('camera')) {
        return (Icons.photo_camera_rounded, isDark ? const Color(0xFF26C6DA) : const Color(0xFF00ACC1));
      }
      return (Icons.auto_awesome_rounded, isDark ? const Color(0xFF9FA8DA) : const Color(0xFF7C4DFF));
    }
    if (a == 'audio_transcription' || d.contains('record') || d.contains('audio')) {
      return (Icons.mic_none_rounded, isDark ? const Color(0xFF42A5F5) : const Color(0xFF1E88E5));
    }
    if (a == 'youtube_link' || d.contains('youtube')) {
      return (Icons.smart_display_rounded, isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F));
    }
    if (a == 'pdf_analysis' || d.contains('pdf')) {
      return (Icons.picture_as_pdf_rounded, isDark ? const Color(0xFFE57373) : const Color(0xFFE53935));
    }
    if (a == 'diagram_image' || d.contains('diagram')) {
      return (Icons.image_rounded, isDark ? const Color(0xFF4DB6AC) : const Color(0xFF00897B));
    }
    if (a == 'quiz' || d.contains('quiz')) {
      return (Icons.quiz_rounded, isDark ? const Color(0xFFFFCA28) : const Color(0xFFFFA000));
    }
    if (a == 'flashcards' || d.contains('flashcard')) {
      return (Icons.style_rounded, isDark ? const Color(0xFF7986CB) : const Color(0xFF3F51B5));
    }
    if (a == 'mind_map' || d.contains('mind map')) {
      return (Icons.account_tree_rounded, isDark ? const Color(0xFFBA68C8) : const Color(0xFF8E24AA));
    }
    if (a == 'revision' || a == 'five_min_revision' || d.contains('revision')) {
      return (Icons.auto_fix_high_rounded, isDark ? const Color(0xFF81C784) : const Color(0xFF43A047));
    }
    if (a == 'important_questions' || d.contains('question')) {
      return (Icons.star_rounded, isDark ? const Color(0xFFFFB74D) : const Color(0xFFFB8C00));
    }
    if (a == 'credit_pack' || a == 'subscription_monthly' || a == 'payment_grant' || d.contains('credit') || d.contains('grant')) {
      return (Icons.stars_rounded, isDark ? const Color(0xFFFFD54F) : const Color(0xFFFFB300));
    }
    if (a == 'refund') {
      return (Icons.undo_rounded, isDark ? const Color(0xFFCE93D8) : const Color(0xFF8E24AA));
    }

    return (Icons.bolt_rounded, isDark ? const Color(0xFFAB47BC) : const Color(0xFF7B1FA2));
  }

  static IconData featureIcon(String? action) {
    return featureTheme(action, null, null as dynamic).$1;
  }

  /// Filter bucket for chips. Grants appear under [filterAll] only.
  static String filterBucket(String? action) {
    final a = normalizeAction(action);
    if (a == 'audio_transcription' || a == 'youtube_link') {
      return filterRecordings;
    }
    if (a == 'ask_ai' ||
        a == 'ask_ai_web' ||
        a == 'home_ai_vision' ||
        a.startsWith('home_ai')) {
      return filterAskAi;
    }
    if (a == 'quiz' ||
        a == 'flashcards' ||
        a == 'revision' ||
        a == 'five_min_revision' ||
        a == 'important_questions' ||
        a == 'mind_map' ||
        a == 'select_ai' ||
        a == 'pdf_analysis' ||
        a == 'diagram_image' ||
        a.startsWith('home_ai_tool_regen_')) {
      return filterStudyTools;
    }
    return filterAll;
  }

  static bool matchesFilter(String? action, String filter) {
    if (filter == filterAll) return true;
    return filterBucket(action) == filter;
  }

  static String contextLine({
    required String? description,
    Map<String, dynamic>? lecture,
  }) {
    final title = (lecture?['title'] as String?)?.trim() ?? '';
    final topic = (lecture?['topic'] as String?)?.trim() ?? '';
    final subject = (lecture?['subject'] as String?)?.trim() ?? '';
    final primary = title.isNotEmpty
        ? title
        : (topic.isNotEmpty ? topic : '');
    if (primary.isNotEmpty) {
      if (subject.isNotEmpty && !primary.toLowerCase().contains(subject.toLowerCase())) {
        return '"$primary" ($subject)';
      }
      return '"$primary"';
    }
    final d = (description ?? '').trim();
    if (d.isEmpty) return '';
    // Prefer a question-like snippet for Ask AI; otherwise first line.
    final first = d.split('\n').first.trim();
    if (first.length <= 60) return first;
    return '${first.substring(0, 57)}…';
  }

  static DateTime? parseCreatedAt(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static String formatTimeLabel(DateTime dt, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final time = _formatClock(dt);
    if (day == today) return 'Today, $time';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, $time';
  }

  static String sectionBucket(DateTime dt, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    if (!day.isBefore(weekStart)) return 'This Week';
    return 'Earlier';
  }

  static const sectionOrder = ['Today', 'Yesterday', 'This Week', 'Earlier'];

  static int monthSpentCredits(List<Map<String, dynamic>> rows, {DateTime? now}) {
    final n = now ?? DateTime.now();
    var sum = 0;
    for (final row in rows) {
      final amount = (row['amount'] as num?)?.toInt() ?? 0;
      if (amount >= 0) continue;
      final dt = parseCreatedAt(row['created_at']);
      if (dt == null) continue;
      if (dt.year == n.year && dt.month == n.month) {
        sum += -amount;
      }
    }
    return sum;
  }

  static Map<String, dynamic>? lectureFromRow(Map<String, dynamic> row) {
    final lec = row['lectures'];
    if (lec is Map<String, dynamic>) return lec;
    if (lec is List && lec.isNotEmpty && lec.first is Map) {
      return Map<String, dynamic>.from(lec.first as Map);
    }
    return null;
  }

  /// Tab indices — must match StudyWorkspace tab order (Notes…Ask AI).
  static const int workspaceTabNotes = 0;
  static const int workspaceTabSummary = 1;
  static const int workspaceTabTranscript = 2;
  static const int workspaceTabFlashcards = 3;
  static const int workspaceTabQuiz = 4;
  static const int workspaceTabRevision = 5;
  static const int workspaceTabAskAi = 6;

  /// Best tab to show for a ledger [action] (defaults to Notes).
  static int workspaceTabIndexForAction(String? action) {
    final a = normalizeAction(action);
    switch (a) {
      case 'flashcards':
        return workspaceTabFlashcards;
      case 'quiz':
        return workspaceTabQuiz;
      case 'revision':
      case 'five_min_revision':
        return workspaceTabRevision;
      case 'ask_ai':
      case 'ask_ai_web':
        return workspaceTabAskAi;
      case 'audio_transcription':
      case 'youtube_link':
      case 'pdf_analysis':
      case 'diagram_image':
      case 'mind_map':
      case 'important_questions':
        return workspaceTabNotes;
      default:
        return workspaceTabNotes;
    }
  }

  /// True when tap should open Study Workspace (read-only navigation).
  static bool canOpenStudyWorkspace(Map<String, dynamic> row) {
    final amount = (row['amount'] as num?)?.toInt() ?? 0;
    if (amount >= 0) return false;
    final id = row['lecture_id'];
    return id != null && id.toString().trim().isNotEmpty;
  }

  static String? lectureIdFromRow(Map<String, dynamic> row) {
    final id = row['lecture_id'];
    if (id == null) return null;
    final s = id.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String _formatClock(DateTime dt) {
    final h24 = dt.hour;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    return '$h12:$m $ampm';
  }
}
