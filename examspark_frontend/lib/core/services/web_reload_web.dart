import 'dart:html' as html;

Future<void> hardReloadWebApp() async {
  html.window.location.reload();
}