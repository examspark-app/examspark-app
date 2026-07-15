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
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be logged in to create a lecture');
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

  /// Used by [StudyWorkspace] to decide whether "Share to Group" should show
  /// (only for `source_type == 'recorded'` lectures). Fails closed (returns
  /// null) so the button simply stays hidden if the fetch fails.
  Future<Map<String, dynamic>?> getLectureMeta(String lectureId) async {
    try {
      final response = await SupabaseClient.instance.client
          .from('lectures')
          .select('id, title, source_type, user_id')
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

    final response = await SupabaseClient.instance.client
        .from('lectures')
        .select('id, title, subject, topic, status, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response as List);
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

  /// Loads processed notes from R2 via FastAPI (Postgres stores paths only).
  /// Returns snake_case keys matching what [NotesResultScreen] already renders.
  Future<Map<String, dynamic>> fetchLectureNotes(String lectureId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured — see API_SETUP.md');
    }

    final accessToken = await _requireAccessToken();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/lectures/$lectureId/notes',
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
      'short_summary': decoded['shortSummary'] ?? '',
      'key_points': decoded['keyPoints'] ?? [],
      'clean_notes': decoded['cleanNotes'] ?? '',
      'important_terms': decoded['importantTerms'] ?? [],
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

  /// Home screen education AI. Optional [lectureId] = open Study Workspace
  /// lecture for Priority 1 RAG. Same credit costs as Ask AI.
  Future<Map<String, dynamic>> homeAi({
    required String query,
    String mode = 'normal',
    String? lectureId,
    String? conversationLanguage,
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

  /// Additive SSE Home AI. On stream failure the caller should fall back to [homeAi].
  Future<Map<String, dynamic>> homeAiStream({
    required String query,
    String mode = 'normal',
    String? lectureId,
    String? conversationLanguage,
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
    return _postSseAi(
      path: '/api/v1/home-ai/stream',
      body: body,
      onToken: onToken,
      onMeta: onMeta,
    );
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
              errorMessage = event['message']?.toString() ?? 'Stream error';
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
    } finally {
      client.close();
    }
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
        if (detail is Map && detail['message'] != null) {
          return detail['message'].toString();
        }
        return detail.toString();
      }
    } catch (_) {}
    final trim = body.trim();
    return trim.isNotEmpty
        ? 'Processing failed ($statusCode): $trim'
        : 'Processing failed ($statusCode).';
  }

  /// FastAPI's HTTPException returns `{"detail": "<message>"}` — surface just
  /// that message so ProcessingScreen can show the real reason (e.g. "This
  /// PDF has little extractable text...") instead of raw JSON/status codes.
  String _extractErrorDetail(http.Response response) {
    return _extractErrorDetailFromBody(response.body, response.statusCode);
  }

  Future<Map<String, dynamic>> invokeExtra({
    required String lectureId,
    required String action,
    required String content,
  }) async {
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
