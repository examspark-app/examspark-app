import 'package:flutter/material.dart';

/// ChatGPT-inspired theme configuration
/// Pure minimal black & white theme with soft teal-green accent
class AppTheme {
  AppTheme._();

  // Accent color (soft teal-green, ChatGPT-style)
  static const Color accentColor = Color(0xFF10A37F);

  // Light mode colors
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightPrimaryText = Color(0xFF0D0D0D);
  static const Color lightSecondaryText = Color(0xFF6E6E6E);
  static const Color lightCardBorder = Color(0xFFE5E5E5);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightAccentTint = Color(0xFF10A37F0D); // 5% opacity

  // Dark mode colors
  static const Color darkBackground = Color(0xFF0D0D0D);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFFA0A0A0);
  static const Color darkCardBorder = Color(0xFF2A2A2A);
  static const Color darkCardBackground = Color(0xFF1A1A1A);
  static const Color darkAccentTint = Color(0xFF10A37F1A); // 10% opacity

  // Common values
  static const double borderRadius = 12.0;
  static const double screenPadding = 16.0;
  static const double elementSpacing = 12.0;
  static const double cardPadding = 16.0;

  /// Light theme data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: accentColor,
        onPrimary: Colors.white,
        surface: lightBackground,
        onSurface: lightPrimaryText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightPrimaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: lightPrimaryText,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(
          color: lightPrimaryText,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: lightPrimaryText,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: lightPrimaryText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: lightPrimaryText,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: lightSecondaryText,
        ),
        labelMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: lightCardBorder, width: 1),
        ),
        color: lightCardBackground,
      ),
    );
  }

  /// Dark theme data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: accentColor,
        onPrimary: Colors.white,
        surface: darkBackground,
        onSurface: darkPrimaryText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkPrimaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: darkPrimaryText,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(
          color: darkPrimaryText,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: darkPrimaryText,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkPrimaryText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: darkPrimaryText,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: darkSecondaryText,
        ),
        labelMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkPrimaryText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: darkCardBorder, width: 1),
        ),
        color: darkCardBackground,
      ),
    );
  }

  /// Get primary text color based on theme brightness
  static Color getPrimaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightPrimaryText
        : darkPrimaryText;
  }

  /// Get secondary text color based on theme brightness
  static Color getSecondaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightSecondaryText
        : darkSecondaryText;
  }

  /// Get card border color based on theme brightness
  static Color getCardBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightCardBorder
        : darkCardBorder;
  }

  /// Get card background color based on theme brightness
  static Color getCardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightCardBackground
        : darkCardBackground;
  }

  /// Get accent tint color based on theme brightness
  static Color getAccentTint(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightAccentTint
        : darkAccentTint;
  }
}
