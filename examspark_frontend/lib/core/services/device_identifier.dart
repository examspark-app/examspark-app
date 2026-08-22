import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

Future<String?> getDeviceIdentifier() async {
  try {
    final info = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await info.androidInfo;
      return android.id.trim().isEmpty ? null : 'android:${android.id}';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = await info.iosInfo;
      final id = ios.identifierForVendor;
      return id == null || id.trim().isEmpty ? null : 'ios:${id.trim()}';
    }
  } catch (_) {
    // Device limits must fail open if platform APIs are unavailable.
  }
  return null;
}
