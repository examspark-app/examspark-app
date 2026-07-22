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
        final d = (description ?? '').trim();
        if (d.isNotEmpty) {
          final first = d.split('\n').first.trim();
          return first.length > 40 ? '${first.substring(0, 37)}…' : first;
        }
        return 'Credit change';
    }
  }

  static IconData featureIcon(String? action) {
    final a = normalizeAction(action);
    switch (a) {
      case 'audio_transcription':
        return Icons.mic_none_rounded;
      case 'youtube_link':
        return Icons.play_circle_outline;
      case 'quiz':
        return Icons.quiz_outlined;
      case 'flashcards':
        return Icons.style_outlined;
      case 'revision':
      case 'five_min_revision':
        return Icons.menu_book_outlined;
      case 'important_questions':
        return Icons.star_outline;
      case 'mind_map':
        return Icons.account_tree_outlined;
      case 'ask_ai':
      case 'ask_ai_web':
        return Icons.chat_bubble_outline;
      case 'home_ai_vision':
        return Icons.photo_camera_outlined;
      case 'select_ai':
        return Icons.text_fields_outlined;
      case 'pdf_analysis':
        return Icons.picture_as_pdf_outlined;
      case 'diagram_image':
        return Icons.image_outlined;
      case 'credit_pack':
      case 'subscription_monthly':
      case 'payment_grant':
        return Icons.add_circle_outline;
      case 'refund':
        return Icons.undo_rounded;
      default:
        if (a.startsWith('home_ai_tool_regen_')) {
          return Icons.autorenew_rounded;
        }
        return Icons.bolt_outlined;
    }
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
