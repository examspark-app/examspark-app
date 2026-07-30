import 'dart:html' as html;

String? readDomTextSelection() {
  try {
    final text = html.window.getSelection()?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  } catch (_) {
    return null;
  }
}
