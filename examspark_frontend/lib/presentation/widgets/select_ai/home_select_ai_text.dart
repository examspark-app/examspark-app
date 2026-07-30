import 'package:flutter/material.dart';

/// Plain selectable Home answer text — no Ask/Explain/Simplify chips.
/// (Those re-asked the same answer; founder removed Jul 18, 2026.)
class HomeSelectAiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Future<void> Function(String actionId, String selectedText)? onAction;

  const HomeSelectAiText({
    super.key,
    required this.text,
    this.onAction,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(text, style: style);
  }
}
