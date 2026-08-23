import 'package:examspark_frontend/presentation/screens/glow_guide/glow_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GlowGuide opens with language choice before categories', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GlowGuideScreen()),
    );

    expect(find.text('Skin Care AI 🌿'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Hindi'), findsOneWidget);
    expect(find.text('Bengali'), findsOneWidget);
    expect(find.text('Auto-detect'), findsOneWidget);
    expect(find.text('Skin Care'), findsNothing);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
  });

  testWidgets('GlowGuide category chip adds the selected category', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GlowGuideScreen()),
    );

    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.tap(find.text('Cloth Guide'));
    await tester.pump();

    expect(find.text('Cloth Guide'), findsNWidgets(2));
  });
}
