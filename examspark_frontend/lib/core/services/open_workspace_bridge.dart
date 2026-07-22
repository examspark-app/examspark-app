import 'package:flutter/foundation.dart';

/// Request to open [StudyWorkspace] from outside the tab shell (e.g. processing done).
class OpenWorkspaceRequest {
  final String lectureId;
  final String title;
  final String? subject;
  final bool fullPage;

  const OpenWorkspaceRequest(
    this.lectureId,
    this.title,
    this.subject, {
    this.fullPage = false,
  });
}

/// Cross-screen bridge: Processing complete → AppShell opens StudyWorkspace.
class OpenWorkspaceBridge extends ChangeNotifier {
  OpenWorkspaceBridge._();
  static final OpenWorkspaceBridge instance = OpenWorkspaceBridge._();

  OpenWorkspaceRequest? _pending;

  void open({
    required String lectureId,
    required String title,
    String? subject,
    bool fullPage = false,
  }) {
    final id = lectureId.trim();
    if (id.isEmpty) return;
    _pending = OpenWorkspaceRequest(
      id,
      title.trim().isEmpty ? 'Lecture' : title.trim(),
      subject,
      fullPage: fullPage,
    );
    notifyListeners();
  }

  OpenWorkspaceRequest? takePending() {
    final p = _pending;
    _pending = null;
    return p;
  }
}
