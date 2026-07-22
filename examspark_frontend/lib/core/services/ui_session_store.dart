import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local UI session — Founder Lock: Session Persistence & Resume.
/// Memory first; SharedPreferences so minimize/remount does not wipe work.
class UiSessionStore {
  UiSessionStore._();
  static final UiSessionStore instance = UiSessionStore._();

  static const _kTab = 'ui_session_tab_index';
  static const _kHomeChat = 'ui_session_home_chat_v1';
  static const _kWorkspace = 'ui_session_workspace_v1';
  static const _kHomeSessionId = 'ui_session_home_ai_session_id';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> saveHomeSessionId(String? sessionId) async {
    final p = await _prefs;
    if (sessionId == null || sessionId.isEmpty) {
      await p.remove(_kHomeSessionId);
    } else {
      await p.setString(_kHomeSessionId, sessionId);
    }
  }

  Future<String?> loadHomeSessionId() async {
    final p = await _prefs;
    return p.getString(_kHomeSessionId);
  }
  Future<void> saveTabIndex(int index) async {
    final p = await _prefs;
    await p.setInt(_kTab, index);
  }

  Future<int?> loadTabIndex() async {
    final p = await _prefs;
    return p.getInt(_kTab);
  }

  Future<void> saveHomeChat(List<Map<String, dynamic>> messages) async {
    final p = await _prefs;
    await p.setString(_kHomeChat, jsonEncode(messages));
  }

  Future<List<Map<String, dynamic>>> loadHomeChat() async {
    final p = await _prefs;
    final raw = p.getString(_kHomeChat);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveWorkspace({
    required String lectureId,
    required String title,
    String? subject,
    bool fullPage = false,
  }) async {
    final p = await _prefs;
    await p.setString(
      _kWorkspace,
      jsonEncode({
        'lectureId': lectureId,
        'title': title,
        'subject': subject,
        'fullPage': fullPage,
      }),
    );
  }

  Future<Map<String, dynamic>?> loadWorkspace() async {
    final p = await _prefs;
    final raw = p.getString(_kWorkspace);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> clearWorkspace() async {
    final p = await _prefs;
    await p.remove(_kWorkspace);
  }
}
