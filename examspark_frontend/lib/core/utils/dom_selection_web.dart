import 'dart:html' as html;
import 'dart:js_util' as js_util;

String? readDomTextSelection() {
  try {
    final selection = html.window.getSelection();
    if (selection == null) return null;

    // dart:html's Selection.toString() can return Dart's default
    // "Instance of 'Selection'" instead of the real JS toString() under
    // some compile targets (e.g. wasm). Call the JS toString() explicitly
    // via js_util to always get the actual selected text.
    final raw = js_util.callMethod(selection, 'toString', []);
    final text = (raw is String ? raw : '').trim();
    if (text.isEmpty) return null;
    return text;
  } catch (_) {
    return null;
  }
}