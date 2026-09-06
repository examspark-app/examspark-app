import 'package:examspark_frontend/presentation/screens/glow_guide/glow_guide_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GlowGuide opens directly to polished category choices', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GlowGuideScreen(startFresh: true)),
    );

    expect(find.text('Skin Care'), findsOneWidget);
    expect(find.text('Hair Care'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('selected category becomes a compact locked receipt', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GlowGuideScreen(startFresh: true)),
    );

    await tester.tap(find.text('Cloth Guide'));
    await tester.pump();

    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Body Care'), findsNothing);
    expect(find.text('What would you like to check about this fabric or garment?'), findsOneWidget);
  });

  testWidgets('category selection does not make an invisible AI request', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GlowGuideScreen(startFresh: true)),
    );

    await tester.tap(find.text('Baby Skin Care'));
    await tester.pump();

    expect(find.text('Tell me your baby’s concern, or share a clear product-label photo.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
