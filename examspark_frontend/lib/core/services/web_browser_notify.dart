import 'package:examspark_frontend/core/services/web_browser_notify_stub.dart'
    if (dart.library.html) 'package:examspark_frontend/core/services/web_browser_notify_web.dart'
    as impl;

/// Browser Notification API helpers (Chrome desktop). Stub on mobile.
Future<String> browserNotifyPermission() => impl.browserNotifyPermission();

Future<String> requestBrowserNotifyPermission() =>
    impl.requestBrowserNotifyPermission();

bool isBrowserDocumentHidden() => impl.isBrowserDocumentHidden();

void showBrowserNotify({
  required String title,
  String? body,
  String? tag,
}) =>
    impl.showBrowserNotify(title: title, body: body, tag: tag);

void onBrowserVisibilityChange(void Function() callback) =>
    impl.onBrowserVisibilityChange(callback);
