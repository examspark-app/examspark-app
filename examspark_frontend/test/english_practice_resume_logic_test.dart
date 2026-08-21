import 'package:flutter_test/flutter_test.dart';
import 'package:examspark_frontend/presentation/screens/english_practice/english_practice_screen.dart';

void main() {
  group('EnglishPracticeScreen resume guard', () {
    test('allows a fresh latest-session resume only when it is the current request', () {
      expect(
        EnglishPracticeScreen.shouldResumeLatestSession(
          resumeLatest: true,
          sessionId: null,
          requestId: 2,
          activeRequestId: 2,
        ),
        isTrue,
      );

      expect(
        EnglishPracticeScreen.shouldResumeLatestSession(
          resumeLatest: true,
          sessionId: 'session-123',
          requestId: 2,
          activeRequestId: 2,
        ),
        isFalse,
      );

      expect(
        EnglishPracticeScreen.shouldResumeLatestSession(
          resumeLatest: true,
          sessionId: null,
          requestId: 1,
          activeRequestId: 2,
        ),
        isFalse,
      );

      expect(
        EnglishPracticeScreen.shouldResumeLatestSession(
          resumeLatest: false,
          sessionId: null,
          requestId: 2,
          activeRequestId: 2,
        ),
        isFalse,
      );

      expect(
        EnglishPracticeScreen.shouldResumeLatestSession(
          resumeLatest: true,
          sessionId: null,
          requestId: 2,
          activeRequestId: 2,
          cancelled: true,
        ),
        isFalse,
      );
    });
  });
}
