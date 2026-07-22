import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';

class LectureService {
  LectureService._();

  static final LectureService instance = LectureService._();

  Future<String> _requireAccessToken() async {
    var session = SupabaseClient.instance.currentSession;
    if (session != null && session.isExpired) {
      try {
        final refreshed = await SupabaseClient.instance.client.auth.refreshSession();
        session = refreshed.session;
      } catch (_) {
        // Fall through — caller gets a clear error below.
      }
    }
    final accessToken = session?.accessToken;
    if (accessToken == null) {
      throw StateError('No active session — please log in again');
    }
    return accessToken;
  }

  /// [sourceType] tracks HOW this lecture's audio/content was captured —
  /// 'recorded' (real mic), 'uploaded_audio', or 'uploaded_document'. Only
  /// 'recorded' lectures are eligible for the "Share to Group" action
  /// (fake-teacher prevention — see teacher_group_features_migration.sql).
  Future<String> createLecture({
    required String title,
    String? subject,
    String? topic,
    bool highAccuracy = false,
    String sourceType = 'recorded',
    /// Only for intentional retries of a failed job — never for YouTube /
    /// generic titles (that caused Library "YouTube Notes" to reopen empty).
    bool reuseRecentSameTitle = false,
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be logged in to create a lecture');
    }

    if (reuseRecentSameTitle) {
      final existing = await _findRecentSameTitle(title, subject, sourceType);
      if (existing != null) return existing;
    }

    final client = SupabaseClient.instance.client;
    final response = await client
        .from('lectures')
        .insert({
          'user_id': userId,
          'title': title,
          'subject': subject,
          'topic': topic,
          'status': 'splitting',
          'high_accuracy': highAccuracy,
          'source_type': sourceType,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  static const _genericTitles = {
    'youtube notes',
    'lecture',
    'untitled',
    'new lecture',
    'recording',
  };

  Future<String?> _findRecentSameTitle(
    String title,
    String? subject,
    String sourceType,
  ) async {
    final t = title.trim().toLowerCase();
    if (t.isEmpty || _genericTitles.contains(t)) return null;
    if (sourceType == 'youtube_link') return null;
    final list = await getLecturesForUser();
    final now = DateTime.now().toUtc();
    for (final lecture in list.take(30)) {
      final lt = ((lecture['title'] as String?) ?? '').trim().toLowerCase();
      if (lt != t) continue;
      if (subject != null && subject.trim().isNotEmpty) {
        final ls = ((lecture['subject'] as String?) ?? '').trim().toLowerCase();
        if (ls != subject.trim().toLowerCase()) continue;
      }
      final created = DateTime.tryParse((lecture['created_at'] as String?) ?? '');
      if (created == null) continue;
      if (now.difference(created.toUtc()).inMinutes <= 10) {
        return lecture['id'] as String?;
      }
    }
    return null;
  }

  /// [errorMessage] is only kept when [status] is `'error'` — any other
  /// status clears it, so a later successful retry doesn't leave a stale
  /// error visible (see `error_message` column, `schema.sql`).
  Future<void> updateStatus(String lectureId, String status, {String? errorMessage}) async {
    await SupabaseClient.instance.client
        .from('lectures')
        .update({
          'status': status,
          'error_message': status == 'error' ? errorMessage : null,
        })
        .eq('id', lectureId);
  }

  /// Current lecture status (+ duplicate pointer). Null if missing / offline.
  Future<Map<String, dynamic>?> getLectureStatusRow(String lectureId) async {
    try {
      final row = await SupabaseClient.instance.client
          .from('lectures')
          .select('id, status, error_message, duplicate_of_lecture_id, title, subject')
          .eq('id', lectureId)
          .maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }

  /// Client HTTP failures must not overwrite a lecture that already finished.
  /// Returns `true` if status was set to error; `false` if already `done`.
  Future<bool> markErrorUnlessDone(String lectureId, String errorMessage) async {
    final row = await getLectureStatusRow(lectureId);
    final status = (row?['status'] as String?)?.toLowerCase();
    if (status == 'done') return false;
    await updateStatus(lectureId, 'error', errorMessage: errorMessage);
    return true;
  }

  /// True when the long `/process` HTTP wait likely died while the server may
  /// still be finishing (Flutter Web / network blips). Not for FEATURE_LOCKED /
  /// credits / validation — those should surface immediately.
  static bool isLikelyProcessNetworkFailure(Object error) {
    final s = error.toString().toLowerCase();
    if (s.contains('feature_locked') ||
        s.contains('insufficient credits') ||
        s.contains('not enough credits') ||
        s.contains('no speech') ||
        s.contains('🔒')) {
      return false;
    }
    const needles = [
      'socket',
      'connection',
      'clientexception',
      'failed host lookup',
      'network',
      'timed out',
      'timeout',
      'connection closed',
      'connection reset',
      'xmlhttprequest',
      'failed to fetch',
      'http request failed',
    ];
    for (final n in needles) {
      if (s.contains(n)) return true;
    }
    return false;
  }

  /// After a dropped long `/process` response: poll status up to [maxWait].
  ///
  /// - `done` → return row (caller must not show error)
  /// - `error` → return row (caller may show that error)
  /// - still in progress when time expires → return last row (may still be
  ///   transcribing/generating — caller should avoid false sticky errors if
  ///   realtime can finish)
  Future<Map<String, dynamic>?> waitOutProcessNetworkBlip(
    String lectureId, {
    Duration maxWait = const Duration(seconds: 90),
    Duration interval = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(maxWait);
    Map<String, dynamic>? last;
    while (DateTime.now().isBefore(deadline)) {
      last = await getLectureStatusRow(lectureId);
      final status = (last?['status'] as String?)?.toLowerCase() ?? '';
      if (status == 'done' || status == 'error') {
        return last;
      }
      // generating / almost_done / transcribing / splitting → keep waiting
      await Future<void>.delayed(interval);
    }
    return last ?? await getLectureStatusRow(lectureId);
  }

  /// Network-blip recovery for [invokeProcessing] failures.
  /// Returns `true` if the caller should **not** mark/show an error (done or
  /// still processing — leave Realtime / ProcessingScreen to finish).
  Future<bool> recoverAfterProcessNetworkBlip(String lectureId) async {
    final row = await waitOutProcessNetworkBlip(lectureId);
    final status = (row?['status'] as String?)?.toLowerCase() ?? '';
    if (status == 'done') return true;
    if (status == 'generating' ||
        status == 'almost_done' ||
        status == 'transcribing' ||
        status == 'splitting') {
      // Server still working past the poll window — do not sticky-error yet.
      return true;
    }
    return false;
  }

  /// Used by [StudyWorkspace] for Share-to-Group eligibility and header meta.
  /// Fails closed (returns null) so UI stays safe if the fetch fails.
  Future<Map<String, dynamic>?> getLectureMeta(String lectureId) async {
    try {
      final response = await SupabaseClient.instance.client
          .from('lectures')
          .select('id, title, subject, source_type, user_id, status, created_at')
          .eq('id', lectureId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getLecturesForUser() async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) return [];

    // Library / Recent only show finished lectures. Draft/error job rows stay
    // in DB for ProcessingScreen retry but must never look like saved files.
    // Sort by last opened (fallback created_at) so "Continue" matches real use.
    final response = await SupabaseClient.instance.client
        .from('lectures')
        .select(
          'id, title, subject, topic, status, created_at, last_opened_at, duplicate_of_lecture_id',
        )
        .eq('user_id', userId)
        .eq('status', 'done')
        .isFilter('duplicate_of_lecture_id', null)
        .order('last_opened_at', ascending: false, nullsFirst: false);

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Bump [last_opened_at] when Study Workspace opens (Library time stamp).
  /// Fails soft — open must never break if the column is missing or offline.
  Future<void> markLectureOpened(String lectureId) async {
    final id = lectureId.trim();
    final userId = SupabaseClient.instance.currentUser?.id;
    if (id.isEmpty || userId == null) return;
    try {
      await SupabaseClient.instance.client
          .from('lectures')
          .update({'last_opened_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .eq('user_id', userId);
    } catch (_) {}
  }

  /// Phase 4: Creates metadata rows only — no content stored in Postgres.
  /// All content (transcript text, notes JSON, summary) is stored in
  /// Cloudflare R2 by the Phase 5 FastAPI pipeline. The R2 paths are written
  /// back to `transcripts.r2_transcript_path` / `notes.r2_notes_path` etc.
  /// by the backend after upload completes.
  Future<void> saveNotes({
    required String lectureId,
    required Map<String, dynamic> processedContent,
    required String transcript,
  }) async {
    final client = SupabaseClient.instance.client;

    // Create the metadata rows so the lecture has transcript + notes records.
    // R2 paths are null until Phase 5 FastAPI writes them after R2 upload.
    await client.from('transcripts').upsert({
      'lecture_id': lectureId,
    });

    await client.from('notes').upsert({
      'lecture_id': lectureId,
    });

    await updateStatus(lectureId, 'done');
  }

  /// Phase 5: FastAPI `/api/v1/lectures/process` — audio (Whisper+Qwen3) or
  /// image (Qwen3-VL) / PDF text (Qwen3). Pass [filename] so the backend can
  /// set the correct MIME / PDF vs image route.
  Future<Map<String, dynamic>> invokeProcessing({
    required String lectureId,
    required Uint8List fileBytes,
    required bool highAccuracy,
    String sourceType = 'recording',
    int? durationMinutes,
    String filename = 'audio.webm',
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be logged in');
    }
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();

    await updateStatus(lectureId, 'transcribing');

    final uri = Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/process');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields['source_type'] = sourceType
      ..fields['lecture_id'] = lectureId
      ..fields['duration_minutes'] = (durationMinutes ?? 60).toString()
      ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// YouTube Link → Notes — captions path (no file upload). Credits 35/65/100 by duration.
  Future<Map<String, dynamic>> invokeYoutubeProcessing({
    required String lectureId,
    required String youtubeUrl,
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be logged in');
    }
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    await updateStatus(lectureId, 'transcribing');

    final uri = Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/process');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields['source_type'] = 'youtube_link'
      ..fields['lecture_id'] = lectureId
      ..fields['youtube_url'] = youtubeUrl;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Loads processed notes via FastAPI (Supabase short fields, R2 fallback).
  Future<Map<String, dynamic>> fetchLectureNotes(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/notes',
    );
    late final http.Response response;
    try {
      response = await http
          .get(
            uri,
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception(
        'Notes load timed out. Check backend is running, then tap Retry.',
      );
    } on Exception catch (e) {
      throw Exception(
        'Notes network error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Notes response was not JSON.');
    }
    final map = Map<String, dynamic>.from(decoded);
    // Accept both camelCase (API) and snake_case.
    return {
      'short_summary': (map['shortSummary'] ?? map['short_summary'] ?? '')
          .toString(),
      'key_points': map['keyPoints'] ?? map['key_points'] ?? [],
      'clean_notes':
          (map['cleanNotes'] ?? map['clean_notes'] ?? '').toString(),
      'important_terms':
          map['importantTerms'] ?? map['important_terms'] ?? [],
      'visual_payload': map['visualPayload'] ?? map['visual_payload'],
    };
  }

  /// Read-only clean transcript from R2 via FastAPI — free, no credits.
  Future<Map<String, dynamic>> fetchTranscript(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/transcript',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'transcript': decoded['transcript'] ?? '',
      'word_count': decoded['wordCount'] ?? 0,
      'available': decoded['available'] == true,
    };
  }

  /// Session 3 — Ask AI / RAG via FastAPI (Notes → Clean Transcript).
  /// [mode] is `normal` (5 credits) or `deep` (12 credits).
  Future<Map<String, dynamic>> askAi({
    required String lectureId,
    required String query,
    String mode = 'normal',
    String? conversationLanguage,
  }) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/ask-ai');
    final body = <String, dynamic>{
      'lecture_id': lectureId,
      'query': query,
      'mode': mode,
    };
    if (conversationLanguage != null && conversationLanguage.isNotEmpty) {
      body['conversation_language'] = conversationLanguage;
    }
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Cached flashcards for a lecture (free read from R2 via FastAPI).
  Future<Map<String, dynamic>> fetchFlashcards(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/flashcards',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Generate flashcards from lecture notes (5 credits, server-side deduct).
  Future<Map<String, dynamic>> generateFlashcards(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/flashcards',
    );
    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Cached quiz MCQs for a lecture (free read).
  Future<Map<String, dynamic>> fetchQuiz(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/quiz',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Generate 20 MCQ quiz from lecture notes (5 credits, server-side deduct).
  Future<Map<String, dynamic>> generateQuiz(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/quiz',
    );
    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Cached revision sheet for a lecture (free read from Supabase via FastAPI).
  Future<Map<String, dynamic>> fetchRevision(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/revision',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Generate revision sheet from lecture notes (5 credits, server-side deduct).
  Future<Map<String, dynamic>> generateRevision(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/revision',
    );
    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Cached 5-minute revision for a lecture (free read).
  Future<Map<String, dynamic>> fetchFiveMinRevision(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/five-min-revision',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Generate short 5-minute revision recap (5 credits, server-side deduct).
  Future<Map<String, dynamic>> generateFiveMinRevision(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/five-min-revision',
    );
    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Cached important questions for a lecture (free read).
  Future<Map<String, dynamic>> fetchImportantQuestions(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/important-questions',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Generate important exam questions from lecture notes (20 credits).
  Future<Map<String, dynamic>> generateImportantQuestions(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/important-questions',
    );
    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Cached mind map for a lecture (free read).
  Future<Map<String, dynamic>> fetchMindMap(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/mind-map',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Generate mind map from lecture notes (30 credits).
  Future<Map<String, dynamic>> generateMindMap(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/mind-map',
    );
    final response = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Home screen education AI. Optional [lectureId] = open Study Workspace
  /// lecture for Priority 1 RAG. Same credit costs as Ask AI.
  Future<Map<String, dynamic>> homeAi({
    required String query,
    String mode = 'normal',
    String? lectureId,
    String? conversationLanguage,
    String? studyChip,
    String? parentResponseId,
    String? sessionId,
  }) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/home-ai');
    final body = <String, dynamic>{
      'query': query,
      'mode': mode,
    };
    if (lectureId != null && lectureId.isNotEmpty) {
      body['lecture_id'] = lectureId;
    }
    if (conversationLanguage != null && conversationLanguage.isNotEmpty) {
      body['conversation_language'] = conversationLanguage;
    }
    if (studyChip != null && studyChip.isNotEmpty) {
      body['study_chip'] = studyChip;
    }
    if (parentResponseId != null && parentResponseId.isNotEmpty) {
      body['parent_response_id'] = parentResponseId;
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      body['session_id'] = sessionId;
    }
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Home AI Camera / Image → chat answer (not Study Workspace).
  /// Credits: [CreditCosts.homeAiVision] (10) server-side after SUCCESS.
  Future<Map<String, dynamic>> homeAiVision({
    required Uint8List imageBytes,
    required String filename,
    String? query,
  }) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }
    final accessToken = await _requireAccessToken();
    final uri =
        Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/home-ai/vision');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields['query'] = (query ?? '').trim()
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: filename,
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Additive SSE Home AI. On stream failure the caller should fall back to [homeAi].
  Future<Map<String, dynamic>> homeAiStream({
    required String query,
    String mode = 'normal',
    String? lectureId,
    String? conversationLanguage,
    String? studyChip,
    String? parentResponseId,
    String? sessionId,
    required void Function(String delta) onToken,
    void Function(Map<String, dynamic> meta)? onMeta,
  }) async {
    final body = <String, dynamic>{
      'query': query,
      'mode': mode,
    };
    if (lectureId != null && lectureId.isNotEmpty) {
      body['lecture_id'] = lectureId;
    }
    if (conversationLanguage != null && conversationLanguage.isNotEmpty) {
      body['conversation_language'] = conversationLanguage;
    }
    if (studyChip != null && studyChip.isNotEmpty) {
      body['study_chip'] = studyChip;
    }
    if (parentResponseId != null && parentResponseId.isNotEmpty) {
      body['parent_response_id'] = parentResponseId;
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      body['session_id'] = sessionId;
    }
    return _postSseAi(
      path: '/api/v1/home-ai/stream',
      body: body,
      onToken: onToken,
      onMeta: onMeta,
    );
  }

  /// Related PYQ tags for a question (0 credits — metadata only).
  Future<Map<String, dynamic>> homeAiPyqRelated(String query) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }
    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/home-ai/pyq-related',
    ).replace(queryParameters: {'q': query, 'limit': '5'});
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Phase 4D — list Study Sessions (0 credits).
  Future<List<Map<String, dynamic>>> homeAiListSessions({
    int limit = 40,
    String? query,
  }) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }
    final accessToken = await _requireAccessToken();
    final params = <String, String>{'limit': '$limit'};
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/home-ai/sessions',
    ).replace(queryParameters: params);
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final list = data['sessions'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Phase 4D — restore session + messages + chip statuses (0 credits, no AI).
  Future<Map<String, dynamic>> homeAiRestoreSession(String sessionId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }
    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/home-ai/sessions/$sessionId',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> homeAiDeleteSession(String sessionId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }
    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/home-ai/sessions/$sessionId',
    );
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }
  }

  /// Permanent owner delete via FastAPI (R2 folder + DB cascade).
  Future<void> deleteLecture(String lectureId) async {
    final id = lectureId.trim();
    if (id.isEmpty) {
      throw StateError('Lecture id is required');
    }
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }
    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$id',
    );
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }
  }

  /// Phase 4C — hydrate chip states for a master Home AI response.
  Future<Map<String, dynamic>> homeAiToolStatuses(String responseId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }
    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/home-ai/responses/$responseId/tools',
    );
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Phase 4C — generate or reuse a chip tool (client sends only ids).
  Future<Map<String, dynamic>> homeAiGenerateTool({
    required String responseId,
    required String toolType,
    bool regenerate = false,
  }) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }
    final accessToken = await _requireAccessToken();
    final suffix = regenerate ? '/regenerate' : '';
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/home-ai/responses/$responseId/tools/$toolType$suffix',
    );
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: '{}',
    );
    if (response.statusCode != 200) {
      throw Exception(_extractErrorDetail(response));
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Additive SSE Ask AI. On stream failure the caller should fall back to [askAi].
  Future<Map<String, dynamic>> askAiStream({
    required String lectureId,
    required String query,
    String mode = 'normal',
    String? conversationLanguage,
    required void Function(String delta) onToken,
    void Function(Map<String, dynamic> meta)? onMeta,
  }) async {
    final body = <String, dynamic>{
      'lecture_id': lectureId,
      'query': query,
      'mode': mode,
    };
    if (conversationLanguage != null && conversationLanguage.isNotEmpty) {
      body['conversation_language'] = conversationLanguage;
    }
    return _postSseAi(
      path: '/api/v1/ask-ai/stream',
      body: body,
      onToken: onToken,
      onMeta: onMeta,
    );
  }

  /// Select & Ask AI (Phase 6) — selection-scoped stream.
  Future<Map<String, dynamic>> selectAiStream({
    required String lectureId,
    required String selectedText,
    required String action,
    String sourceSurface = 'notes',
    String? followupQuery,
    String? conversationLanguage,
    required void Function(String delta) onToken,
    void Function(Map<String, dynamic> meta)? onMeta,
  }) async {
    final body = <String, dynamic>{
      'lecture_id': lectureId,
      'selected_text': selectedText,
      'action': action,
      'source_surface': sourceSurface,
    };
    if (followupQuery != null && followupQuery.isNotEmpty) {
      body['followup_query'] = followupQuery;
    }
    if (conversationLanguage != null && conversationLanguage.isNotEmpty) {
      body['conversation_language'] = conversationLanguage;
    }
    return _postSseAi(
      path: '/api/v1/select-ai/stream',
      body: body,
      onToken: onToken,
      onMeta: onMeta,
    );
  }

  Future<Map<String, dynamic>> _postSseAi({
    required String path,
    required Map<String, dynamic> body,
    required void Function(String delta) onToken,
    void Function(Map<String, dynamic> meta)? onMeta,
  }) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse('${AppConfig.resolvedApiBaseUrl}$path');
    final request = http.Request('POST', uri);
    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    });
    request.body = jsonEncode(body);

    final client = http.Client();
    try {
      // Hard cap so Home AI never sits spinning for minutes if the server hangs.
      return await _readSseAi(
        client: client,
        request: request,
        onToken: onToken,
        onMeta: onMeta,
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw Exception(
            'Home AI timed out after 120s. Restart the FastAPI backend '
            '(port 8000), then try again.',
          );
        },
      );
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _readSseAi({
    required http.Client client,
    required http.Request request,
    required void Function(String delta) onToken,
    void Function(Map<String, dynamic> meta)? onMeta,
  }) async {
    final streamed = await client.send(request);
    if (streamed.statusCode != 200) {
      final errBody = await streamed.stream.bytesToString();
      throw Exception(_extractErrorDetailFromBody(errBody, streamed.statusCode));
    }

    final buffer = StringBuffer();
    Map<String, dynamic>? donePayload;
    String? errorMessage;

    await for (final chunk in streamed.stream.transform(utf8.decoder)) {
      buffer.write(chunk);
      var raw = buffer.toString();
      var sep = raw.indexOf('\n\n');
      while (sep >= 0) {
        final block = raw.substring(0, sep);
        raw = raw.substring(sep + 2);
        final event = _parseSseDataBlock(block);
        if (event != null) {
          final type = event['type'] as String?;
          if (type == 'token') {
            final text = event['text'] as String? ?? '';
            if (text.isNotEmpty) onToken(text);
          } else if (type == 'meta') {
            onMeta?.call(event);
          } else if (type == 'done') {
            donePayload = event;
          } else if (type == 'error') {
            final msg = event['message']?.toString() ?? 'Stream error';
            final code =
                event['code']?.toString() ?? event['status']?.toString();
            if (code == 'FEATURE_LOCKED') {
              errorMessage = msg.startsWith('🔒') ? msg : '🔒 $msg';
            } else {
              errorMessage = msg;
            }
          }
        }
        sep = raw.indexOf('\n\n');
      }
      buffer
        ..clear()
        ..write(raw);
    }

    if (errorMessage != null) {
      throw Exception(errorMessage);
    }
    if (donePayload == null) {
      throw Exception('Stream ended without a done event');
    }
    return donePayload;
  }

  Map<String, dynamic>? _parseSseDataBlock(String block) {
    for (final line in block.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.startsWith('data:')) {
        final payload = trimmed.substring(5).trim();
        if (payload.isEmpty || payload == '[DONE]') return null;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is Map) {
            return Map<String, dynamic>.from(decoded);
          }
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  String _extractErrorDetailFromBody(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'];
        if (detail is Map) {
          final message = detail['message']?.toString();
          final code = detail['code']?.toString() ?? detail['status']?.toString();
          if (message != null && message.isNotEmpty) {
            if (code == 'FEATURE_LOCKED') {
              return message.startsWith('🔒') ? message : '🔒 $message';
            }
            return message;
          }
        }
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        return detail.toString();
      }
    } catch (_) {}
    final trim = body.trim();
    return trim.isNotEmpty
        ? 'Processing failed ($statusCode): $trim'
        : 'Processing failed ($statusCode).';
  }

  /// FastAPI HTTPException detail — including Session 5 FEATURE_LOCKED payload
  /// (`detail.message` + `detail.code`). Surface the message for ProcessingScreen.
  String _extractErrorDetail(http.Response response) {
    return _extractErrorDetailFromBody(response.body, response.statusCode);
  }

  Future<Map<String, dynamic>> invokeExtra({
    required String lectureId,
    required String action,
    required String content,
  }) async {
    final normalized = action.toLowerCase();
    if (AppConfig.isApiConfigured) {
      if (normalized == 'flashcards' || normalized == 'flashcard') {
        return generateFlashcards(lectureId);
      }
      if (normalized == 'mcq' || normalized == 'quiz') {
        return generateQuiz(lectureId);
      }
      if (normalized == 'revision' || normalized == 'revision_sheet') {
        return generateRevision(lectureId);
      }
      if (normalized == 'important_questions' ||
          normalized == 'important-questions') {
        return generateImportantQuestions(lectureId);
      }
      if (normalized == 'mind_map' || normalized == 'mind-map') {
        return generateMindMap(lectureId);
      }
    }

    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be logged in');
    }

    final response = await SupabaseClient.instance.client.functions.invoke(
      'process-lecture',
      body: {
        'action': action,
        'userId': userId,
        'lectureId': lectureId,
        'content': content,
        'query': content,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Extra generation failed: ${response.data}');
  }
}
