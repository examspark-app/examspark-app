import 'package:examspark_frontend/core/services/lecture_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isLikelyProcessNetworkFailure', () {
    test('detects connection / timeout errors', () {
      expect(
        LectureService.isLikelyProcessNetworkFailure(
          Exception('ClientException: Connection closed'),
        ),
        isTrue,
      );
      expect(
        LectureService.isLikelyProcessNetworkFailure(
          Exception('SocketException: Connection reset'),
        ),
        isTrue,
      );
      expect(
        LectureService.isLikelyProcessNetworkFailure(
          Exception('TimeoutException after 0:01:00'),
        ),
        isTrue,
      );
    });

    test('does not treat credits / lock / no-speech as network', () {
      expect(
        LectureService.isLikelyProcessNetworkFailure(
          Exception('Insufficient credits: balance 2 < required 5'),
        ),
        isFalse,
      );
      expect(
        LectureService.isLikelyProcessNetworkFailure(
          Exception('FEATURE_LOCKED'),
        ),
        isFalse,
      );
      expect(
        LectureService.isLikelyProcessNetworkFailure(
          Exception('No speech detected. Kindly check your microphone'),
        ),
        isFalse,
      );
    });
  });
}
