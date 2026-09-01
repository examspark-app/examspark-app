import 'package:flutter_test/flutter_test.dart';
import 'package:examspark_frontend/core/services/feature_analytics_tracker.dart';

void main() {
  test('tracks home ai page visit and usage duration by feature', () async {
    final events = <({String eventName, Map<String, dynamic> properties})>[];
    final tracker = FeatureAnalyticsTracker(
      onEvent: (eventName, properties) {
        events.add((eventName: eventName, properties: properties));
      },
    );

    tracker.startFeature('home_ai');

    await Future<void>.delayed(const Duration(milliseconds: 25));

    tracker.stopFeature('home_ai');

    expect(events.length, 2);
    expect(events[0].eventName, 'home_ai_page_view');
    expect(events[0].properties['feature'], 'home_ai');
    expect(events[1].eventName, 'home_ai_usage_duration');
    expect(events[1].properties['feature'], 'home_ai');
    expect(events[1].properties['duration_seconds'], isA<int>());
    expect(events[1].properties['duration_seconds'], greaterThanOrEqualTo(0));
  });
}
