import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';

/// Teacher coupon create / redeem via FastAPI.
class CouponService {
  CouponService._();
  static final CouponService instance = CouponService._();

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

  Future<Map<String, dynamic>> createCoupon(String classId) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured');
    }
    final token = await _token();
    final res = await http.post(
      Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/coupons/create'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'class_id': classId}),
    );
    if (res.statusCode != 200) {
      throw Exception(_detail(res));
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listMyCoupons() async {
    if (!AppConfig.isApiConfigured) return [];
    final token = await _token();
    final res = await http.get(
      Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/coupons/mine'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['coupons'] as List? ?? []);
  }

  Future<Map<String, dynamic>> redeemCoupon(String code) async {
    if (!AppConfig.isApiConfigured) {
      throw StateError('FASTAPI_BASE_URL not configured');
    }
    final token = await _token();
    final res = await http.post(
      Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/coupons/redeem'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'code': code.trim()}),
    );
    if (res.statusCode != 200) {
      throw Exception(_detail(res));
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  String _detail(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['detail'] != null) return body['detail'].toString();
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }
}
