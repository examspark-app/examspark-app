import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/constants/certificate_upload_rules.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';

/// Soft AI Get Verified — POST /api/v1/teachers/verify-certificate
class TeacherVerificationService {
  TeacherVerificationService._();
  static final TeacherVerificationService instance =
      TeacherVerificationService._();

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

  Future<Map<String, dynamic>> verifyCertificate({
    required List<int> imageBytes,
    required String filename,
    String? title,
  }) async {
    final nameErr = CertificateUploadRules.validateFilename(filename);
    if (nameErr != null) throw StateError(nameErr);

    if (!AppConfig.isApiConfigured) {
      throw StateError('API not configured — set API_BASE_URL in .env');
    }
    final token = await _token();
    final uri = Uri.parse(
      '${AppConfig.resolvedApiBaseUrl}/api/v1/teachers/verify-certificate',
    );
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    if (title != null && title.trim().isNotEmpty) {
      req.fields['title'] = title.trim();
    }
    final ct = CertificateUploadRules.contentTypeFor(filename);
    final parts = ct.split('/');
    final mime = MediaType(
      parts.isNotEmpty ? parts[0] : 'image',
      parts.length > 1 ? parts[1] : 'jpeg',
    );
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: filename,
        contentType: mime,
      ),
    );
    late http.Response res;
    try {
      final streamed = await req.send().timeout(const Duration(seconds: 75));
      res = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 75));
    } on http.ClientException catch (e) {
      throw Exception(
        'Cannot reach the server. Please try again in a moment.',
      );
    } on TimeoutException {
      throw Exception(
        'Verification is taking too long. Use a smaller JPG/PDF (<3 MB) and retry.',
      );
    }
    if (res.statusCode != 200) {
      String detail = 'Verification failed (${res.statusCode})';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['detail'] != null) {
          detail = body['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }
}
