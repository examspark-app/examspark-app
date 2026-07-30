import 'package:flutter/material.dart';
import 'package:examspark_frontend/core/theme/app_theme.dart';

/// Reusable avatar: shows a network photo if [photoUrl] is provided,
/// otherwise falls back to the person's initials on an accent-tinted circle.
///
/// Placeholder-friendly: works fine with a null [photoUrl] since no real
/// photo storage (Cloudflare R2) is wired up yet.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;

  const InitialsAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 48,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: AppTheme.getAccentTint(context),
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppTheme.getAccentTint(context),
      child: Text(
        _initials,
        style: TextStyle(
          color: AppTheme.accentColor,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
