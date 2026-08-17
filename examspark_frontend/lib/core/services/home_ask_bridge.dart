/// Cross-screen bridge:
/// Select text → Reply → Home composer → user asks follow-up → AI sends.
class HomeAskBridge {
  HomeAskBridge._();

  static final HomeAskBridge instance = HomeAskBridge._();

  String? _pendingSelection;
  String? _pendingQuestion;

  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  /// Queue selected text as a reply/reference for the Home composer.
  void requestReply(String selectedText) {
    final text = selectedText.trim();
    if (text.isEmpty) return;

    _pendingSelection = text;
    _pendingQuestion = null;

    _notify();
  }

  /// Queue a normal Home question.
  void requestAsk(String question) {
    final q = question.trim();
    if (q.isEmpty) return;

    _pendingQuestion = q;
    _pendingSelection = null;

    _notify();
  }

  /// Read and clear pending selection.
  String? takePendingSelection() {
    final value = _pendingSelection;
    _pendingSelection = null;
    return value;
  }

  /// Read and clear pending question.
  String? takePendingQuestion() {
    final value = _pendingQuestion;
    _pendingQuestion = null;
    return value;
  }

  void clearPending() {
    _pendingSelection = null;
    _pendingQuestion = null;
  }

  void _notify() {
    for (final listener in List<void Function()>.from(_listeners)) {
      listener();
    }
  }
}

/// Build the AI payload when the user sends a follow-up
/// about selected text.
String homeFollowUpPrompt({
  required String selectedText,
  required String question,
}) {
  final selected = selectedText.trim();
  final q = question.trim();

  if (selected.isEmpty) return q;
  if (q.isEmpty) return selected;

  return '''
The user selected this text from the previous AI response:

"$selected"

Now answer the user's follow-up question:

$q
''';
}