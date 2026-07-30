/// Persists the anonymous "1 free prompt" so refreshing / reopening the app
/// does not reset the trial. Clearing browser site data / app data can still
/// reset this — real guest Ask AI must also rate-limit by IP on FastAPI later.
library;

import 'package:shared_preferences/shared_preferences.dart';

class GuestTrialStore {
  GuestTrialStore._();

  static const _usedKey = 'examspark_guest_free_prompt_used_v1';
  static const _usedAtKey = 'examspark_guest_free_prompt_used_at_v1';

  static Future<bool> isFreePromptUsed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_usedKey) ?? false;
  }

  static Future<void> markFreePromptUsed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_usedKey, true);
    await prefs.setString(_usedAtKey, DateTime.now().toUtc().toIso8601String());
  }
}
