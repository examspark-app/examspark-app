import 'dart:js_interop';

@JS('forceReloadExamSparkApp')
external void _forceReloadExamSparkAppJS();

/// Web only — calls the JS function defined in index.html.
void forceReloadExamSparkApp() {
  try {
    _forceReloadExamSparkAppJS();
  } catch (_) {}
}