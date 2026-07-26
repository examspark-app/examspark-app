import 'package:shared_preferences/shared_preferences.dart';

/// Remembers invite join code across Sign Up / email verify / Google redirect.
/// Cleared after the group page opens successfully.
class PendingInviteStore {
  PendingInviteStore._();

  static const _key = 'sonaxia_pending_join_code_v1';

  static Future<void> save(String joinCode) async {
    final code = joinCode.trim().toUpperCase();
    if (code.length < 4) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  static Future<String?> peek() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key)?.trim().toUpperCase();
    if (code == null || code.length < 4) return null;
    return code;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
