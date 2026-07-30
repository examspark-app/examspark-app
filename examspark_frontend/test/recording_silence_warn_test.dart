import 'package:examspark_frontend/core/services/recording_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldFireSilenceWarning', () {
    test('no voice yet — first warn at 5 seconds', () {
      expect(
        RecordingService.shouldFireSilenceWarning(
          consecutiveSilentSeconds: 4,
          heardAnyVoice: false,
          lastWarnAtElapsed: null,
        ),
        isFalse,
      );
      expect(
        RecordingService.shouldFireSilenceWarning(
          consecutiveSilentSeconds: 5,
          heardAnyVoice: false,
          lastWarnAtElapsed: null,
        ),
        isTrue,
      );
    });

    test('no voice — repeat every 300 silent seconds after first warn', () {
      expect(
        RecordingService.shouldFireSilenceWarning(
          consecutiveSilentSeconds: 299,
          heardAnyVoice: false,
          lastWarnAtElapsed: 5,
        ),
        isFalse,
      );
      expect(
        RecordingService.shouldFireSilenceWarning(
          consecutiveSilentSeconds: 300,
          heardAnyVoice: false,
          lastWarnAtElapsed: 5,
        ),
        isTrue,
      );
    });

    test('heard voice — no 5s nag, only 300s silent stretch', () {
      expect(
        RecordingService.shouldFireSilenceWarning(
          consecutiveSilentSeconds: 5,
          heardAnyVoice: true,
          lastWarnAtElapsed: null,
        ),
        isFalse,
      );
      expect(
        RecordingService.shouldFireSilenceWarning(
          consecutiveSilentSeconds: 300,
          heardAnyVoice: true,
          lastWarnAtElapsed: null,
        ),
        isTrue,
      );
    });
  });
}
