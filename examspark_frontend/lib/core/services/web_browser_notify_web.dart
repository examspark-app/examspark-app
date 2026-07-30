// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<String> browserNotifyPermission() async =>
    html.Notification.permission ?? 'default';

Future<String> requestBrowserNotifyPermission() async {
  final result = await html.Notification.requestPermission();
  return result ?? 'default';
}

bool isBrowserDocumentHidden() => html.document.hidden ?? false;

void showBrowserNotify({
  required String title,
  String? body,
  String? tag,
}) {
  if ((html.Notification.permission ?? 'default') != 'granted') return;
  try {
    html.Notification(
      title,
      body: body,
      tag: tag,
    );
  } catch (_) {}
}

void onBrowserVisibilityChange(void Function() callback) {
  html.document.onVisibilityChange.listen((_) => callback());
}
