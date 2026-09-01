import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
class _SessionInfo {
  _SessionInfo(this.featureName, this.startedAt);
  final String featureName;
  final DateTime startedAt;
}
/// Tracks page-view + usage-duration events per feature and sends them to
/// PostHog. Use the singleton via [FeatureAnalyticsTracker.instance].
class FeatureAnalyticsTracker with WidgetsBindingObserver {
  FeatureAnalyticsTracker._({this.onEvent}) {
    WidgetsBinding.instance.addObserver(this);
  }
 
  static final FeatureAnalyticsTracker instance = FeatureAnalyticsTracker._();

  /// Optional hook, mainly for tests — when set, events are routed here
  /// instead of being sent to PostHog.
  final void Function(String eventName, Map<String, dynamic> properties)?
      onEvent;

  final Map<String, _SessionInfo> _sessionStarts = {};

  String startFeature(String featureName) {
    final cleanName = _normalizeFeatureName(featureName);
    final now = DateTime.now();
    final sessionKey = '${cleanName}_${now.microsecondsSinceEpoch}';
    _sessionStarts[sessionKey] = _SessionInfo(cleanName, now);
    _capture('${cleanName}_page_view', {
      'feature': cleanName,
      'page': cleanName,
      'opened_at': now.toIso8601String(),
    });
    return sessionKey;
  }

  void stopFeature(String? sessionKey) {
    if (sessionKey == null) return;
    final info = _sessionStarts.remove(sessionKey);
    if (info == null) return;
    _emitDuration(info.featureName, info.startedAt);
  }

  /// Force-closes every still-open session. Called automatically when the
  /// app is backgrounded/detached so a missed `stopFeature()` call (crash,
  /// killed process, skipped dispose) never permanently blocks that
  /// feature's future page-view events, and so the duration is still
  /// captured instead of lost.
  void _stopAllOpenSessions() {
    final openKeys = _sessionStarts.keys.toList();
    for (final key in openKeys) {
      final info = _sessionStarts.remove(key);
      if (info != null) {
        _emitDuration(info.featureName, info.startedAt);
      }
    }
  }

  void _emitDuration(String cleanName, DateTime startedAt) {
    final now = DateTime.now();
    final elapsed = now.difference(startedAt);
    _capture('${cleanName}_usage_duration', {
      'feature': cleanName,
      'page': cleanName,
      'duration_seconds': elapsed.inSeconds,
      'duration_ms': elapsed.inMilliseconds,
      'opened_at': startedAt.toIso8601String(),
      'closed_at': now.toIso8601String(),
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopAllOpenSessions();
    }
  }

  String _normalizeFeatureName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  void _capture(String eventName, Map<String, dynamic> properties) {
    final payload = <String, Object>{
      for (final entry in properties.entries)
        if (entry.value != null) entry.key: entry.value as Object,
    };

    if (onEvent != null) {
      onEvent!(eventName, payload);
      return;
    }

    try {
      Posthog().capture(eventName: eventName, properties: payload);
    } catch (_) {
      // Analytics is non-blocking and should never crash the app.
    }
  }

  /// Call this from your app's dispose/teardown path (e.g. in tests, or if
  /// you ever tear down the app shell) to avoid leaking the observer.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}