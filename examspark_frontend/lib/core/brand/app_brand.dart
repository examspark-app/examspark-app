import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Consumer brand — single source for visible product name (launcher + UI).
class AppBrand {
  AppBrand._();

  /// User-facing app name (Home, Login, launcher).
  static const String name = 'Sonaxia';

  /// Mark letter inside the brand tile.
  static const String markLetter = 'S';

  /// MaterialApp / system title.
  static const String materialTitle = name;

  /// Public web host for invite / QR links (Cloudflare Pages + your domain).
  /// Not Railway — Railway hosts FastAPI only (e.g. api.sonaxia.com later).
  static const String publicWebHost = 'sonaxia.com';

  /// Invite URL → opens app on `/#/join/{code}` → teacher Group page.
  /// Local Chrome: uses current origin so link lands in this app immediately.
  static String inviteJoinUrl(String joinCode) {
    final code = joinCode.trim().toUpperCase();
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && !origin.contains('sonaxia.com')) {
        // Dev / localhost / preview: land in this running app.
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
