import 'package:examspark_frontend/presentation/widgets/smart_educational_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject(VisualPayloadData payload) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SmartEducationalContent(
            markdownBody: '',
            visualPayload: payload,
          ),
        ),
      ),
    );
  }

  testWidgets('renders a quadratic graph with implicit multiplication', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        VisualPayloadData.fromJson({
          'graphs': [
            {
              'function': 'y=x^2-5x+6',
              'x_range': [-2, 7],
              'label': 'Parabola with roots 2 and 3',
            },
          ],
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Parabola with roots 2 and 3'), findsOneWidget);
  });

  testWidgets('renders a biology text diagram', (tester) async {
    await tester.pumpWidget(
      subject(
        VisualPayloadData.fromJson({
          'text_diagrams': [
            {'title': 'Cell structure', 'content': 'Membrane\n↓\nNucleus'},
          ],
        }),
      ),
    );

    expect(find.text('Cell structure'), findsOneWidget);
    expect(find.text('Membrane\n↓\nNucleus'), findsOneWidget);
  });

  testWidgets('renders a history timeline', (tester) async {
    await tester.pumpWidget(
      subject(
        VisualPayloadData.fromJson({
          'timelines': [
            {'period': '1857', 'label': 'Revolt'},
          ],
        }),
      ),
    );

    expect(find.text('1857'), findsOneWidget);
    expect(find.text('Revolt'), findsOneWidget);
  });
}
