import 'package:flutter/foundation.dart';

/// Cross-tab bridge: "New chat" / recent-chat taps from the App Drawer
/// (which lives outside HomeTab, in AppShell) tell Home to reset or
/// restore a session. Mirrors HomeAskBridge / OpenWorkspaceBridge already
/// used in this app.
class HomeSessionBridge extends ChangeNotifier {
  HomeSessionBridge._();
  static final HomeSessionBridge instance = HomeSessionBridge._();

  String? _pendingRestoreSessionId;
  bool _pendingNewChat = false;

  void requestNewChat() {
    _pendingNewChat = true;
    notifyListeners();
  }

  void requestRestoreSession(String sessionId) {
    _pendingRestoreSessionId = sessionId;
    notifyListeners();
  }

  bool takePendingNewChat() {
    final v = _pendingNewChat;
    _pendingNewChat = false;
    return v;
  }

  String? takePendingRestoreSessionId() {
    final id = _pendingRestoreSessionId;
    _pendingRestoreSessionId = null;
    return id;
  }
}