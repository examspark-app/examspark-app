import 'package:examspark_frontend/presentation/screens/glow_guide/glow_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GlowGuide opens with categories and combined input', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GlowGuideScreen()),
    );

    expect(find.text('GlowGuide 🌿'), findsOneWidget);
    expect(find.text('Skin Care'), findsOneWidget);
    expect(find.text('Body Care'), findsOneWidget);
    expect(find.text('Baby Skin Care'), findsOneWidget);
    expect(find.text('Cloth Guide'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
  });

  testWidgets('GlowGuide category chip adds the selected category', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GlowGuideScreen()),
    );

    await tester.tap(find.text('Cloth Guide'));
    await tester.pump();

    expect(find.text('Cloth Guide'), findsNWidgets(2));
  });
}
