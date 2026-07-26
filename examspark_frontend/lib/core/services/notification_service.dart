import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:examspark_frontend/core/config/app_config.dart';
import 'package:examspark_frontend/core/network/supabase_client.dart';

/// Per-group unread preview for WhatsApp-style Groups list.
class GroupUnreadInfo {
  final int count;
  final String? lastPreview;

  const GroupUnreadInfo({required this.count, this.lastPreview});
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

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

  Future<List<Map<String, dynamic>>> listNotifications() async {
    if (!AppConfig.isApiConfigured) return [];
    try {
      // Catch-up subscription expiry alerts before listing (deduped server-side).
      await checkSubscriptionExpiry();
      final token = await _token();
      final res = await http.get(
        Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(
        body['notifications'] as List? ?? [],
      );
    } catch (_) {
      return [];
    }
  }

  DateTime? _lastExpiryCheckAt;

  /// Best-effort: 7d / 3d / 1d / expired (server dedupes). Throttled client-side.
  Future<void> checkSubscriptionExpiry({bool force = false}) async {
    if (!AppConfig.isApiConfigured) return;
    final now = DateTime.now();
    if (!force &&
        _lastExpiryCheckAt != null &&
        now.difference(_lastExpiryCheckAt!) < const Duration(hours: 6)) {
      return;
    }
    try {
      final token = await _token();
      await http.post(
        Uri.parse(
          '${AppConfig.resolvedApiBaseUrl}/api/v1/notifications/check-subscription-expiry',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      _lastExpiryCheckAt = now;
    } catch (_) {}
  }

  /// Unread counts + last preview keyed by class_id (for Groups list).
  Future<Map<String, GroupUnreadInfo>> unreadByClass() async {
    final items = await listNotifications();
    final map = <String, GroupUnreadInfo>{};
    for (final n in items) {
      final classId = n['class_id'] as String?;
      if (classId == null || classId.isEmpty) continue;
      final readAt = n['read_at'];
      if (readAt != null) continue;
      final prev = map[classId];
      final body = (n['body'] as String?)?.trim();
      map[classId] = GroupUnreadInfo(
        count: (prev?.count ?? 0) + 1,
        lastPreview: prev?.lastPreview ?? (body?.isNotEmpty == true ? body : null),
      );
    }
    return map;
  }

  Future<void> markRead(String notificationId) async {
    if (!AppConfig.isApiConfigured) return;
    final token = await _token();
    await http.post(
      Uri.parse(
        '${AppConfig.resolvedApiBaseUrl}/api/v1/notifications/$notificationId/read',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> markClassRead(String classId) async {
    if (!AppConfig.isApiConfigured || classId.isEmpty) return;
    try {
      final token = await _token();
      await http.post(
        Uri.parse(
          '${AppConfig.resolvedApiBaseUrl}/api/v1/notifications/class/$classId/read',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  Future<void> notifyShare({
    required String classId,
    required String title,
    String body = '',
    String? sharedItemId,
  }) async {
    if (!AppConfig.isApiConfigured) return;
    try {
      final token = await _token();
      await http.post(
        Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/groups/share-notify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'class_id': classId,
          'title': title,
          'body': body,
          if (sharedItemId != null) 'shared_item_id': sharedItemId,
        }),
      );
    } catch (_) {
      // Soft-fail — share already succeeded.
    }
  }

  Future<void> registerDeviceToken(
    String fcmToken, {
    String platform = 'android',
  }) async {
    if (!AppConfig.isApiConfigured || fcmToken.isEmpty) return;
    try {
      final token = await _token();
      await http.post(
        Uri.parse('${AppConfig.resolvedApiBaseUrl}/api/v1/coupons/device-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': fcmToken, 'platform': platform}),
      );
    } catch (_) {}
  }

  static String defaultPlatform() {
    if (kIsWeb) return 'web';
    return 'android';
  }
}
