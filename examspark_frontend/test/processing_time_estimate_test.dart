import 'package:examspark_frontend/core/utils/processing_time_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('short recording — about 1–3 min window', () {
    final e = ProcessingTimeEstimate.fromInputs(
      sourceType: 'recording',
      durationMinutes: 2,
      fileBytes: 800 * 1024,
    );
    expect(e.typicalLowSeconds, lessThan(180));
    expect(e.typicalHighSeconds, greaterThan(e.typicalLowSeconds));
    expect(e.totalRangeLabel, contains('min'));
  });

  test('long recording — high end larger than short clip', () {
    final short = ProcessingTimeEstimate.fromInputs(
      sourceType: 'recording',
      durationMinutes: 3,
    );
    final long = ProcessingTimeEstimate.fromInputs(
      sourceType: 'recording',
      durationMinutes: 45,
    );
    expect(long.typicalHighSeconds, greaterThan(short.typicalHighSeconds));
  });

  test('elapsed line stays honest inside window', () {
    final e = ProcessingTimeEstimate.fromInputs(
      sourceType: 'recording',
      durationMinutes: 5,
    );
    final line = e.elapsedLine(
      elapsed: Duration(seconds: e.typicalLowSeconds + 10),
      stage: ProcessingEstimateStage.transcribing,
    );
    expect(line, contains('Still processing'));
  });

  test('youtube faster base than 60 min audio', () {
    final yt = ProcessingTimeEstimate.fromInputs(
      sourceType: 'youtube_link',
      durationMinutes: 30,
    );
    final audio = ProcessingTimeEstimate.fromInputs(
      sourceType: 'recording',
      durationMinutes: 30,
    );
    expect(yt.typicalHighSeconds, lessThan(audio.typicalHighSeconds));
  });
}
