import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';

/// Teacher dashboard student list + performance via FastAPI.
class TeacherStudentsService {
  TeacherStudentsService._();
  static final TeacherStudentsService instance = TeacherStudentsService._();

  Future<String> _token() async {
    var session = SupabaseClient.instance.currentSession;
    if (session != null && session.isExpired) {
      try {
        final refreshed =
            await SupabaseClient.instance.client.auth.refreshSession();
        session = refreshed.session;
      } catch (_) {}
    }
    final t = session?.accessToken;
    if (t == null) throw StateError('Please log in again');
    return t;
  }

  /// Returns students + daily_active_count (opened a group in last 24h).
  Future<Map<String, dynamic>> listStudentsPayload() async {
    if (!AppConfig.isApiConfigured) {
      return {
        'students': <Map<String, dynamic>>[],
        'daily_active_count': 0,
        'total_students': 0,
      };
    }
    final token = await _token();
    final res = await http.get(
      Uri.parse(
        '${AppConfig.resolvedApiBaseUrl}/api/v1/groups/teacher/students',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception(_detail(res));
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['students'];
    final students = list is List
        ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final daily = body['daily_active_count'];
    final total = body['total_students'];
    return {
      'students': students,
      'daily_active_count': daily is num ? daily.toInt() : 0,
      'total_students': total is num ? total.toInt() : students.length,
    };
  }

  Future<List<Map<String, dynamic>>> listStudents() async {
    final payload = await listStudentsPayload();
    return List<Map<String, dynamic>>.from(payload['students'] as List);
  }

  String _detail(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) {
        return body['detail'].toString();
      }
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }
}
