import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:examspark_frontend/core/services/notification_service.dart';
import 'package:examspark_frontend/core/services/web_browser_notify.dart';

/// In-app unread badge + Chrome desktop tray alerts while Sonaxia tab
/// stays open (even if you switch to another website tab).
///
/// Closed-tab push needs full Firebase Web Push (later) — this covers
/// desktop multi-tab use without Firebase web config.
class NotificationInboxController extends ChangeNotifier {
  NotificationInboxController._();
  static final NotificationInboxController instance =
      NotificationInboxController._();

  static const _kNotifyStudy = 'settings_notify_study';
  static const _kNotifyGroups = 'settings_notify_groups';
  static const _kAlertedIds = 'notif_desktop_alerted_ids';

  int unreadCount = 0;
  bool _started = false;
  Timer? _poll;
  final Set<String> _alertedIds = {};
  bool _visibilityHooked = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _loadAlertedIds();
    if (kIsWeb && !_visibilityHooked) {
      _visibilityHooked = true;
      onBrowserVisibilityChange(() {
        unawaited(refresh(showDesktopIfHidden: true));
      });
    }
    await refresh(showDesktopIfHidden: false);
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 25), (_) {
      unawaited(refresh(showDesktopIfHidden: true));
    });
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
    _started = false;
    unreadCount = 0;
    notifyListeners();
  }

  Future<void> _loadAlertedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kAlertedIds) ?? const [];
      _alertedIds
        ..clear()
        ..addAll(raw);
    } catch (_) {}
  }

  Future<void> _persistAlertedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Cap list so prefs stay small.
      final list = _alertedIds.toList();
      if (list.length > 80) {
        final trimmed = list.sublist(list.length - 80);
        _alertedIds
          ..clear()
          ..addAll(trimmed);
        await prefs.setStringList(_kAlertedIds, trimmed);
      } else {
        await prefs.setStringList(_kAlertedIds, list);
      }
    } catch (_) {}
  }

  Future<int> refresh({required bool showDesktopIfHidden}) async {
    final items = await NotificationService.instance.listNotifications();
    final unread = <Map<String, dynamic>>[];
    for (final n in items) {
      if (n['read_at'] != null) continue;
      unread.add(n);
    }
    final nextCount = unread.length;
    if (nextCount != unreadCount) {
      unreadCount = nextCount;
      notifyListeners();
    } else {
      unreadCount = nextCount;
    }

    if (kIsWeb && showDesktopIfHidden) {
      await _maybeDesktopAlerts(unread);
    }
    return unreadCount;
  }

  Future<void> _maybeDesktopAlerts(List<Map<String, dynamic>> unread) async {
    // Only when user left Sonaxia tab (another page / minimized).
    if (!isBrowserDocumentHidden()) return;
    if (await browserNotifyPermission() != 'granted') return;

    final prefs = await SharedPreferences.getInstance();
    final allowStudy = prefs.getBool(_kNotifyStudy) ?? true;
    final allowGroups = prefs.getBool(_kNotifyGroups) ?? true;

    var changed = false;
    for (final n in unread) {
      final id = n['id'] as String?;
      if (id == null || id.isEmpty || _alertedIds.contains(id)) continue;

      final event = (n['event_type'] as String?) ?? '';
      final isGroupish = event.startsWith('join_') ||
          event.contains('share') ||
          event.contains('announce') ||
          (n['class_id'] as String?)?.isNotEmpty == true;
      final isStudyOrPlan = event.startsWith('expiring_') ||
          event == 'expired' ||
          event == 'payment_success' ||
          event == 'payment_failed' ||
          event.contains('lecture') ||
          event.contains('notes');

      if (isGroupish && !allowGroups) {
        _alertedIds.add(id);
        changed = true;
        continue;
      }
      if (isStudyOrPlan && !allowStudy && !isGroupish) {
        _alertedIds.add(id);
        changed = true;
        continue;
      }

      final title = (n['title'] as String?)?.trim();
      final body = (n['body'] as String?)?.trim();
      showBrowserNotify(
        title: (title == null || title.isEmpty) ? 'Sonaxia' : title,
        body: body,
        tag: id,
      );
      _alertedIds.add(id);
      changed = true;
    }
    if (changed) await _persistAlertedIds();
  }

  Future<void> markReadLocally(String notificationId) async {
    _alertedIds.add(notificationId);
    await _persistAlertedIds();
    await refresh(showDesktopIfHidden: false);
  }

  Future<String> enableDesktopBrowserAlerts() async {
    if (!kIsWeb) return 'unsupported';
    final result = await requestBrowserNotifyPermission();
    if (result == 'granted') {
      await refresh(showDesktopIfHidden: true);
    }
    return result;
  }
}
