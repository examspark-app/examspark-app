import 'package:examspark_frontend/presentation/widgets/ai_model_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows selected AI model and all text-model choices', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiModelSelector(
            selectedModel: 'gemini',
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('Gemini Flash'), findsOneWidget);
    await tester.tap(find.byType(AiModelSelector));
    await tester.pumpAndSettle();

    expect(find.text('Qwen3'), findsOneWidget);
    expect(find.text('Gemini Flash'), findsWidgets);
    expect(find.text('Claude Premium'), findsOneWidget);

    await tester.tap(find.text('Claude Premium'));
    expect(selected, 'claude');
  });
}
