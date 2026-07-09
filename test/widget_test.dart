import 'package:flutter_test/flutter_test.dart';
import 'package:examspark_frontend/main.dart';

void main() {
  testWidgets('Recording setup screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const ExamSparkApp());

    expect(find.text('Recording Setup'), findsOneWidget);
    expect(find.text('Start Recording'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Lecture Topic'), findsOneWidget);
  });
}
