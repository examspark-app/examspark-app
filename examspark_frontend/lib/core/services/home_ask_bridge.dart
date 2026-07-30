/// Cross-screen bridge: Select text → Ask AI → Home chat sends the question.
class HomeAskBridge {
  HomeAskBridge._();
  static final HomeAskBridge instance = HomeAskBridge._();

  String? _pending;
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Queue a Home Ask from anywhere (Study Workspace, sheets, etc.).
  void requestAsk(String selectedOrQuestion) {
    final q = selectedOrQuestion.trim();
    if (q.isEmpty) return;
    _pending = q;
    for (final l in List<void Function()>.from(_listeners)) {
      l();
    }
  }

  String? takePending() {
    final q = _pending;
    _pending = null;
    return q;
  }
}

/// Build the chat question from highlighted text + Select action.
String homeAskPromptFromSelection(String selected, {String actionId = 'ask_followup'}) {
  final s = selected.trim();
  if (s.isEmpty) return '';
  switch (actionId) {
    case 'simplify':
      return 'Simplify this for a Class 11 student in simple words:\n\n"$s"';
    case 'explain':
      return 'Explain this clearly step-by-step for exam prep:\n\n"$s"';
    case 'ask_followup':
    default:
      if (s.length < 120 && !s.contains('\n')) {
        return s;
      }
      return 'Explain this clearly for a student:\n\n"$s"';
  }
}
