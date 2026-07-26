/// Full Firebase Cloud Messaging — phone home + lock screen + in-app open group.
///
/// Soft-fails when Firebase / `google-services.json` is not configured yet
/// (Chrome web + local without Firebase still runs).
/// Founder setup: examspark_backend/FOUNDER_FCM_SETUP.md
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:examspark_frontend/core/router/app_navigation.dart';
import 'package:examspark_frontend/core/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> examsparkFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('FCM background: ${message.messageId} ${message.data}');
}

class FcmPushService {
  FcmPushService._();
  static final FcmPushService instance = FcmPushService._();

  bool _started = false;
  StreamSubscription<RemoteMessage>? _onMessage;
  StreamSubscription<RemoteMessage>? _onOpened;

  bool get isStarted => _started;

  /// Call once from main() after WidgetsFlutterBinding.
  Future<void> start() async {
    if (_started) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('FCM: Firebase.initializeApp skipped ($e). '
          'Add google-services.json — see FOUNDER_FCM_SETUP.md');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(
      examsparkFirebaseMessagingBackgroundHandler,
    );

    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      debugPrint('FCM permission: $e');
    }

    // Android 13+ / iOS — also helps lock-screen delivery.
    try {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    _onMessage = FirebaseMessaging.onMessage.listen(_onForeground);
    _onOpened = FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      // Defer until navigator is ready.
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        _openFromMessage(initial);
      });
    }

    await registerTokenWithBackend();
    messaging.onTokenRefresh.listen((_) => registerTokenWithBackend());

    _started = true;
    debugPrint('FCM: started');
  }

  Future<void> registerTokenWithBackend() async {
    if (!_firebaseReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await NotificationService.instance.registerDeviceToken(
        token,
        platform: NotificationService.defaultPlatform(),
      );
      debugPrint('FCM: token registered with backend');
    } catch (e) {
      debugPrint('FCM register token: $e');
    }
  }

  bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _onForeground(RemoteMessage message) {
    debugPrint('FCM foreground: ${message.notification?.title}');
    // System tray still shows on Android when notification payload present;
    // in-app Groups list refreshes via SessionLiveSync / pull.
  }

  void _openFromMessage(RemoteMessage message) {
    final classId = message.data['class_id']?.toString();
    final nav = AppNavigation.key.currentState;
    if (nav == null) return;
    final route = message.data['route']?.toString();
    final type = message.data['type']?.toString() ?? '';
    if (route == 'subscription' ||
        type.startsWith('expiring_') ||
        type == 'expired' ||
        type == 'payment_success' ||
        type == 'payment_failed') {
      nav.pushNamed('/subscription');
      return;
    }
    if (classId == null || classId.isEmpty) return;
    NotificationService.instance.markClassRead(classId);
    if (route == 'group_dashboard' || type == 'join_pending_teacher') {
      nav.pushNamed(
        '/group_dashboard',
        arguments: {'classId': classId, 'name': 'Study Group'},
      );
      return;
    }
    nav.pushNamed('/group_info', arguments: {'groupId': classId});
  }

  Future<void> dispose() async {
    await _onMessage?.cancel();
    await _onOpened?.cancel();
  }
}

/// Back-compat helper used after login.
class FcmRegistration {
  FcmRegistration._();

  static Future<void> registerIfPossible([String? ignored]) async {
    await FcmPushService.instance.registerTokenWithBackend();
  }

  static Future<void> ensureStarted() async {
    if (kIsWeb) {
      // Web push needs VAPID + extra Firebase web config — Android first.
      try {
        await FcmPushService.instance.start();
      } catch (_) {}
      return;
    }
    await FcmPushService.instance.start();
  }
}
