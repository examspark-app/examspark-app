import 'package:flutter/services.dart' show SystemSound, SystemSoundType;

/// Native (Android / iOS / desktop) — system alert beep.
Future<void> playRecordingAlertSound({bool urgent = false}) async {
  SystemSound.play(SystemSoundType.alert);
  if (urgent) {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    SystemSound.play(SystemSoundType.alert);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    SystemSound.play(SystemSoundType.click);
  } else {
    SystemSound.play(SystemSoundType.click);
  }
}

/// No-op on native — system sounds need no unlock.
Future<void> unlockRecordingAlertSound() async {}
