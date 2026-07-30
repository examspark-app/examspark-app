import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/constants/credit_history_display.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';
import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:examspark_frontend/core/services/quiz_attempt_service.dart';

/// Slice 1+A live Progress — lectures, study spend, quiz attempts.
/// Never Home AI chats, private notes, or conversation text.
class ProgressActivityItem {
  final IconData icon;
  final String title;
  final String line2;
  final String? line3;
  final DateTime at;

  const ProgressActivityItem({
    required this.icon,
    required this.title,
    required this.line2,
    this.line3,
    required this.at,
  });
}

class ProgressSnapshot {
  final int streakDays;
  final int topicsMastered;
  final int lectureCount;
  /// Average quiz accuracy % from saved attempts; null until first finish.
  final int? learningScorePercent;
  final String? strongSubject;
  final int strongCount;
  final String? weakSubject;
  final int weakCount;
  final String? recommendPrimary;
  final String? recommendSecondary;
  final List<int> weeklyCounts;
  final List<String> weeklyLabels;
  final List<ProgressActivityItem> recent;

  const ProgressSnapshot({
    required this.streakDays,
    required this.topicsMastered,
    required this.lectureCount,
    this.learningScorePercent,
    this.strongSubject,
    this.strongCount = 0,
    this.weakSubject,
    this.weakCount = 0,
    this.recommendPrimary,
    this.recommendSecondary,
    required this.weeklyCounts,
    required this.weeklyLabels,
    required this.recent,
  });

  static ProgressSnapshot empty() {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    return ProgressSnapshot(
      streakDays: 0,
      topicsMastered: 0,
      lectureCount: 0,
      learningScorePercent: null,
      weeklyCounts: List<int>.filled(7, 0),
      weeklyLabels: ProgressService.weekLabelsEnding(day),
      recent: const [],
    );
  }
}

class ProgressService {
  ProgressService._();
  static final ProgressService instance = ProgressService._();

  /// Study-tool spend only — never Home AI / Ask chat / payments.
  static const _studyActions = {
    'audio_transcription',
    'youtube_link',
    'quiz',
    'flashcards',
    'revision',
    'five_min_revision',
    'important_questions',
    'mind_map',
    'pdf_analysis',
    'diagram_image',
  };

  Future<ProgressSnapshot> load() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return ProgressSnapshot.empty();

    final lectures = await LectureService.instance.getLecturesForUser();
    List<Map<String, dynamic>> txs = const [];
    try {
      txs = await SupabaseClient.instance.getCreditTransactions(userId, limit: 40);
    } catch (_) {
      txs = const [];
    }
    final attempts = await QuizAttemptService.instance.listRecent(limit: 30);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final activityDays = <DateTime>{};
    for (final lec in lectures) {
      final created = _parseLocalDay(lec['created_at'] as String?);
      final opened = _parseLocalDay(lec['last_opened_at'] as String?);
      if (created != null) activityDays.add(created);
      if (opened != null) activityDays.add(opened);
    }
    for (final a in attempts) {
      final day = _parseLocalDay(a['created_at'] as String?);
      if (day != null) activityDays.add(day);
    }

    final streak = _computeStreak(activityDays, today);
    final topics = _topicsMastered(lectures);
    final subjectCounts = _subjectCounts(lectures);
    final strong = _pickStrong(subjectCounts);
    final weak = _pickWeak(subjectCounts, strong?.key);
    final recommend = _recommendNext(lectures, weak?.key);
    final weekly = _weeklyCounts(lectures, today);
    final recent = _recentActivity(lectures, txs, attempts);
    final learning = QuizAttemptService.learningScorePercent(attempts);

    return ProgressSnapshot(
      streakDays: streak,
      topicsMastered: topics,
      lectureCount: lectures.length,
      learningScorePercent: learning,
      strongSubject: strong?.key,
      strongCount: strong?.value ?? 0,
      weakSubject: weak?.key,
      weakCount: weak?.value ?? 0,
      recommendPrimary: recommend.$1,
      recommendSecondary: recommend.$2,
      weeklyCounts: weekly,
      weeklyLabels: weekLabelsEnding(today),
      recent: recent,
    );
  }

  static DateTime? _parseLocalDay(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day);
  }

  static DateTime? _parseLocalDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// Consecutive days with lecture save/open. If today is empty, still count
  /// a streak ending yesterday (student may not have opened yet today).
  static int _computeStreak(Set<DateTime> days, DateTime today) {
    if (days.isEmpty) return 0;
    var cursor = days.contains(today) ? today : today.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;
    var count = 0;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static int _topicsMastered(List<Map<String, dynamic>> lectures) {
    final keys = <String>{};
    for (final lec in lectures) {
      final topic = ((lec['topic'] as String?) ?? '').trim();
      final subject = ((lec['subject'] as String?) ?? '').trim();
      final key = topic.isNotEmpty
          ? topic.toLowerCase()
          : (subject.isNotEmpty ? subject.toLowerCase() : '');
      if (key.isNotEmpty) keys.add(key);
    }
    return keys.length;
  }

  static Map<String, int> _subjectCounts(List<Map<String, dynamic>> lectures) {
    final map = <String, int>{};
    for (final lec in lectures) {
      final subject = ((lec['subject'] as String?) ?? '').trim();
      if (subject.isEmpty) continue;
      map[subject] = (map[subject] ?? 0) + 1;
    }
    return map;
  }

  static MapEntry<String, int>? _pickStrong(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    MapEntry<String, int>? best;
    for (final e in counts.entries) {
      if (best == null ||
          e.value > best.value ||
          (e.value == best.value && e.key.compareTo(best.key) < 0)) {
        best = e;
      }
    }
    return best;
  }

  static MapEntry<String, int>? _pickWeak(
    Map<String, int> counts,
    String? strongKey,
  ) {
    if (counts.isEmpty) return null;
    if (counts.length == 1) return null;
    MapEntry<String, int>? weak;
    for (final e in counts.entries) {
      if (strongKey != null && e.key == strongKey) continue;
      if (weak == null ||
          e.value < weak.value ||
          (e.value == weak.value && e.key.compareTo(weak.key) < 0)) {
        weak = e;
      }
    }
    return weak;
  }

  static (String?, String?) _recommendNext(
    List<Map<String, dynamic>> lectures,
    String? weakSubject,
  ) {
    if (lectures.isEmpty) {
      return (
        'Record or open a lecture',
        'Progress builds from your Library',
      );
    }

    Map<String, dynamic>? pick;
    if (weakSubject != null) {
      for (final lec in lectures) {
        final s = ((lec['subject'] as String?) ?? '').trim();
        if (s.toLowerCase() != weakSubject.toLowerCase()) continue;
        pick = lec;
        break; // already sorted last_opened desc — first = most recent in weak
      }
    }
    pick ??= lectures.first;

    final title = ((pick['title'] as String?) ?? '').trim();
    final topic = ((pick['topic'] as String?) ?? '').trim();
    final subject = ((pick['subject'] as String?) ?? '').trim();
    final primary = topic.isNotEmpty
        ? 'Revise $topic'
        : (title.isNotEmpty ? 'Open $title' : 'Continue studying');
    final secondary = subject.isNotEmpty
        ? '$subject · Review notes · Practice quiz'
        : 'Review notes · Practice quiz';
    return (primary, secondary);
  }

  static List<String> weekLabelsEnding(DateTime today) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final out = <String>[];
    for (var i = 6; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      out.add(letters[d.weekday - 1]);
    }
    return out;
  }

  static List<int> _weeklyCounts(
    List<Map<String, dynamic>> lectures,
    DateTime today,
  ) {
    final counts = List<int>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final day = today.subtract(Duration(days: 6 - i));
      final ids = <String>{};
      for (final lec in lectures) {
        final id = (lec['id'] as String?) ?? '';
        if (id.isEmpty) continue;
        final created = _parseLocalDay(lec['created_at'] as String?);
        final opened = _parseLocalDay(lec['last_opened_at'] as String?);
        if (created == day || opened == day) ids.add(id);
      }
      counts[i] = ids.length;
    }
    return counts;
  }

  static List<ProgressActivityItem> _recentActivity(
    List<Map<String, dynamic>> lectures,
    List<Map<String, dynamic>> txs,
    List<Map<String, dynamic>> attempts,
  ) {
    final items = <ProgressActivityItem>[];

    for (final a in attempts) {
      final at = _parseLocalDateTime(a['created_at'] as String?);
      if (at == null) continue;
      final score = a['score'];
      final total = a['total'];
      if (score is! num || total is! num || total <= 0) continue;

      final lec = a['lectures'];
      String? title;
      String? subject;
      if (lec is Map) {
        title = (lec['title'] as String?)?.trim();
        subject = (lec['subject'] as String?)?.trim();
      }

      items.add(
        ProgressActivityItem(
          icon: Icons.quiz_outlined,
          title: 'Quiz Completed',
          line2: (subject != null && subject.isNotEmpty)
              ? subject
              : ((title != null && title.isNotEmpty) ? title : 'Library'),
          line3: '${score.toInt()}/${total.toInt()}',
          at: at,
        ),
      );
    }

    for (final tx in txs) {
      final action = CreditHistoryDisplay.normalizeAction(tx['action'] as String?);
      if (!_studyActions.contains(action)) continue;
      final at = _parseLocalDateTime(tx['created_at'] as String?);
      if (at == null) continue;

      final lec = tx['lectures'];
      String? title;
      String? subject;
      if (lec is Map) {
        title = (lec['title'] as String?)?.trim();
        subject = (lec['subject'] as String?)?.trim();
      }

      items.add(
        ProgressActivityItem(
          icon: CreditHistoryDisplay.featureIcon(action),
          title: CreditHistoryDisplay.featureLabel(
            action,
            tx['description'] as String?,
          ),
          line2: (subject != null && subject.isNotEmpty)
              ? subject
              : ((title != null && title.isNotEmpty) ? title : 'Library'),
          line3: (title != null &&
                  title.isNotEmpty &&
                  subject != null &&
                  subject.isNotEmpty)
              ? title
              : null,
          at: at,
        ),
      );
    }

    // Fill with newest saved lectures when spend history is thin.
    if (items.length < 5) {
      final sorted = [...lectures];
      sorted.sort((a, b) {
        final da = _parseLocalDateTime(a['created_at'] as String?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = _parseLocalDateTime(b['created_at'] as String?) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      for (final lec in sorted) {
        if (items.length >= 8) break;
        final at = _parseLocalDateTime(lec['created_at'] as String?);
        if (at == null) continue;
        final title = ((lec['title'] as String?) ?? '').trim();
        final subject = ((lec['subject'] as String?) ?? '').trim();
        if (title.isNotEmpty &&
            items.any((i) => i.line3 == title || i.line2 == title)) {
          continue;
        }
        items.add(
          ProgressActivityItem(
            icon: Icons.note_alt_outlined,
            title: 'Notes Ready',
            line2: subject.isNotEmpty
                ? subject
                : (title.isNotEmpty ? title : 'Lecture'),
            line3: subject.isNotEmpty && title.isNotEmpty ? title : null,
            at: at,
          ),
        );
      }
    }

    items.sort((a, b) => b.at.compareTo(a.at));
    if (items.length > 8) return items.sublist(0, 8);
    return items;
  }
}
