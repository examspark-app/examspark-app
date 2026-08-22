import 'package:shared_preferences/shared_preferences.dart';

class PendingReferralStore {
  PendingReferralStore._();
  static const _key = 'sonaxia_pending_referral_code_v1';

  static Future<void> save(String code) async {
    final value = code.trim().toUpperCase();
    if (value.length < 4) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }

  static Future<String?> peek() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
