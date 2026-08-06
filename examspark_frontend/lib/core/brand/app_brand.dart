import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Consumer brand — single source for visible product name (launcher + UI).
class AppBrand {
  AppBrand._();

  /// User-facing app name (Home, Login, launcher).
  static const String name = 'Sonaxia';

  /// Mark letter (fallback if image is not available)
  static const String markLetter = 'S';

  /// Path for image placed in `examspark_frontend/web/images/sonaxia_logo.png`
  static const String logoPath = 'images/sonaxia_logo.png';

  /// MaterialApp / system title.
  static const String materialTitle = name;

  /// Public web host for invite / QR links.
  static const String publicWebHost = 'sonaxia.com';

  /// Invite URL → opens app on `/#/join/{code}` → teacher Group page.
  static String inviteJoinUrl(String joinCode) {
    final code = joinCode.trim().toUpperCase();
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.contains('sonaxia.com')) {
        return '$origin/#/join/$code';
      }
    }
    return 'https://$publicWebHost/#/join/$code';
  }

  /// High-visibility wordmark — one consistent look everywhere.
  static TextStyle wordmarkStyle(
    BuildContext context, {
    double fontSize = 18,
  }) {
    final base = Theme.of(context).textTheme.bodyLarge;
    return (base ?? const TextStyle()).copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
      height: 1.1,
      color: AppTheme.getPrimaryText(context),
    );
  }

  static TextStyle heroWordmarkStyle(BuildContext context) {
    return wordmarkStyle(context, fontSize: 28).copyWith(
      letterSpacing: 0.6,
    );
  }
}