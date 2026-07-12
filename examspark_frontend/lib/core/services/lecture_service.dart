import 'dart:convert';
import 'dart:typed_data';

import 'package:examspark_frontend/core/network/supabase_client.dart';

class LectureService {
  LectureService._();

  static final LectureService instance = LectureService._();

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

  Future<void> updateStatus(String lectureId, String status) async {
    await SupabaseClient.instance.client
        .from('lectures')
        .update({'status': status})
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

  Future<Map<String, dynamic>> invokeProcessing({
    required String lectureId,
    required Uint8List audioBytes,
    required bool highAccuracy,
  }) async {
    final userId = SupabaseClient.instance.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be logged in');
    }

    await updateStatus(lectureId, 'transcribing');

    final response = await SupabaseClient.instance.client.functions.invoke(
      'process-lecture',
      body: {
        'input_type': 'audio',
        'audioData': base64Encode(audioBytes),
        'high_accuracy': highAccuracy,
        'userId': userId,
        'lectureId': lectureId,
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Processing failed: ${response.data}');
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
