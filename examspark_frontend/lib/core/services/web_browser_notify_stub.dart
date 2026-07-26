Future<String> browserNotifyPermission() async => 'denied';

Future<String> requestBrowserNotifyPermission() async => 'denied';

bool isBrowserDocumentHidden() => false;

void showBrowserNotify({
  required String title,
  String? body,
  String? tag,
}) {}

void onBrowserVisibilityChange(void Function() callback) {}
