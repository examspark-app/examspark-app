import 'dart:async';
import 'dart:isolate';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class CrashlyticsService {
  CrashlyticsService._();
  static final instance = CrashlyticsService._();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    try {
      final crashlytics = FirebaseCrashlytics.instance;
      FlutterError.onError = crashlytics.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(crashlytics.recordError(error, stack, fatal: true));
        return true;
      };
      Isolate.current.addErrorListener(
        RawReceivePort((pair) async {
          final values = pair as List<dynamic>;
          await crashlytics.recordError(
            values.first,
            StackTrace.fromString(values.length > 1 ? '${values[1]}' : ''),
            fatal: true,
          );
        }).sendPort,
      );
      _initialized = true;
    } catch (_) {
      // Crash reporting must never block app startup.
    }
  }

  void triggerTestCrash() {
    throw StateError('Sonaxia Crashlytics test crash');
  }
}
