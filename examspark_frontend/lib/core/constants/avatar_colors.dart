import 'package:flutter/material.dart';

/// Avatar background colours offered on the student onboarding screen.
/// Stored as a hex string in `users.avatar_color` (e.g. `#10A37F`) —
/// avoids needing image upload / Cloudflare R2 wiring just for a profile
/// picture placeholder.
const List<Color> kAvatarColors = [
  Color(0xFF10A37F),
  Color(0xFF4285F4),
  Color(0xFFEA4335),
  Color(0xFFFBBC05),
  Color(0xFF9C27B0),
  Color(0xFFFF7043),
];

String colorToHex(Color color) {
  return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
}

Color hexToColor(String? hex, {Color fallback = const Color(0xFF10A37F)}) {
  if (hex == null || hex.isEmpty) return fallback;
  final cleaned = hex.replaceAll('#', '');
  final value = int.tryParse('FF$cleaned', radix: 16);
  return value != null ? Color(value) : fallback;
}
