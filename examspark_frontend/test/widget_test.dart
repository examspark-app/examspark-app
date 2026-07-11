import 'package:flutter_test/flutter_test.dart';
import 'package:examspark_frontend/main.dart';

void main() {
  testWidgets('App launches with login screen when Supabase not initialized', (WidgetTester tester) async {
    await tester.pumpWidget(const ExamSparkApp());
    await tester.pump();

    expect(find.text('Sign In'), findsOneWidget);
  });
}
