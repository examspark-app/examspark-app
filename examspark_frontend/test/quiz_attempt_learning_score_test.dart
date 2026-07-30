import 'package:flutter_test/flutter_test.dart';
import 'package:examspark_frontend/core/services/quiz_attempt_service.dart';

void main() {
  test('learningScorePercent averages accuracy', () {
    expect(QuizAttemptService.learningScorePercent([]), isNull);
    expect(
      QuizAttemptService.learningScorePercent([
        {'score': 16, 'total': 20},
        {'score': 10, 'total': 20},
      ]),
      65,
    );
    expect(
      QuizAttemptService.learningScorePercent([
        {'score': 20, 'total': 20},
      ]),
      100,
    );
  });
}
