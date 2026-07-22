import 'package:examspark_frontend/core/network/supabase_client.dart';

/// Persists finished Study Workspace quiz scores for Progress Learning Score.
/// Soft-fail — never block the quiz results UI if offline / SQL not run yet.
class QuizAttemptService {
  QuizAttemptService._();
  static final QuizAttemptService instance = QuizAttemptService._();

  Future<void> recordAttempt({
    required String lectureId,
    required int score,
    required int total,
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    final lid = lectureId.trim();
    if (userId == null || lid.isEmpty || total <= 0) return;
    final safeScore = score.clamp(0, total);

    try {
      await SupabaseClient.instance.client.from('quiz_attempts').insert({
        'user_id': userId,
        'lecture_id': lid,
        'score': safeScore,
        'total': total,
      });
    } catch (_) {
      // Table missing or RLS — Progress stays "—" until SQL is run.
    }
  }

  /// Recent attempts for Progress (newest first). Empty if table missing.
  Future<List<Map<String, dynamic>>> listRecent({int limit = 30}) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return const [];
    try {
      final response = await SupabaseClient.instance.client
          .from('quiz_attempts')
          .select(
            'id, score, total, lecture_id, created_at, '
            'lectures(title, subject, topic)',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      return const [];
    }
  }

  /// Average accuracy % over recent attempts, or null if none.
  static int? learningScorePercent(List<Map<String, dynamic>> attempts) {
    if (attempts.isEmpty) return null;
    var sumPct = 0.0;
    var n = 0;
    for (final a in attempts) {
      final score = a['score'];
      final total = a['total'];
      if (score is! num || total is! num || total <= 0) continue;
      sumPct += (score / total) * 100.0;
      n++;
    }
    if (n == 0) return null;
    return (sumPct / n).round().clamp(0, 100);
  }
}
