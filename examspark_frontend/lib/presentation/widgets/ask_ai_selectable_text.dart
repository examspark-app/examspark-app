import 'package:flutter/material.dart';

/// Called with the text the user had selected when they tapped "Ask AI".
typedef AskAiCallback = void Function(String selectedText);

/// Drop-in [SelectableText] replacement that adds an "Ask AI" button to the
/// default text-selection toolbar (next to Copy / Select All).
///
/// Long-press or drag-select any lecture/study text rendered with this
/// widget and "Ask AI" appears alongside the usual Copy/Select All actions —
/// tapping it hands the selected snippet to [onAskAi], which the caller
/// wires to the existing Ask AI chat (see `RAGChatModal.initialQuery` in
/// `notes_result_screen.dart`). No new backend call or credit cost is
/// introduced here — this only adds a faster entry point into the Ask AI
/// flow that already exists.
class AskAiSelectableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final AskAiCallback onAskAi;

  const AskAiSelectableText({
    super.key,
    required this.text,
    required this.onAskAi,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: style,
      contextMenuBuilder: (context, editableTextState) {
        final value = editableTextState.textEditingValue;
        final selectedText = value.selection.textInside(value.text).trim();

        final buttonItems = <ContextMenuButtonItem>[
          if (selectedText.isNotEmpty)
            ContextMenuButtonItem(
              onPressed: () {
                editableTextState.hideToolbar();
                onAskAi(selectedText);
              },
              label: 'Ask AI',
            ),
          ...editableTextState.contextMenuButtonItems,
        ];

        return AdaptiveTextSelectionToolbar.buttonItems(
          anchors: editableTextState.contextMenuAnchors,
          buttonItems: buttonItems,
        );
      },
    );
  }
}
