import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ChatGPT-inspired theme configuration — black & white professional look
class AppTheme {
  AppTheme._();

  // Neutral black/grey accent (no green) — ChatGPT-style monochrome
  static const Color accentColor = Color(0xFF101010);
  static const Color lightBackground = Color(0xFFF9F9F9); // Soft off-white
  static const Color lightPrimaryText = Color(0xFF0D0D0D);
  static const Color lightSecondaryText = Color(0xFF545454);
  static const Color lightCardBorder = Color(0xFFE5E5E5);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightAccentTint = Color(0x0A000000);
  
  static const Color darkBackground = Color(0xFF212121); // Soft charcoal
  static const Color darkPrimaryText = Color(0xFFECECEC);
  static const Color darkSecondaryText = Color(0xFFB4B4B4);
  static const Color darkCardBorder = Color(0xFF383838);
  static const Color darkCardBackground = Color(0xFF2F2F2F);
  static const Color darkAccentTint = Color(0x14FFFFFF);
  
  // Dark mode accent (buttons) — white on black, ChatGPT dark-mode style
  static const Color darkAccentColor = Color(0xFFFFFFFF);
  
  static const double borderRadius = 12.0;
  static const double screenPadding = 16.0;
  static const double elementSpacing = 16.0;
  static const double cardPadding = 16.0;

  static TextTheme get _lightTextTheme => GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: lightPrimaryText,
            height: 1.3,
            letterSpacing: -0.5,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: lightPrimaryText,
            height: 1.65, // Highly readable for long AI text
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: lightPrimaryText,
            height: 1.6,
          ),
          bodySmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: lightSecondaryText,
            height: 1.5,
          ),
          labelMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      );

  static TextTheme get _darkTextTheme => GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: darkPrimaryText,
            height: 1.3,
            letterSpacing: -0.5,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: darkPrimaryText,
            height: 1.65, // Highly readable for long AI text
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: darkPrimaryText,
            height: 1.6,
          ),
          bodySmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: darkSecondaryText,
            height: 1.5,
          ),
          labelMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: darkPrimaryText,
          ),
        ),
      );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: const ColorScheme.light(
        primary: accentColor,
        onPrimary: Colors.white,
        surface: lightBackground,
        onSurface: lightPrimaryText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightPrimaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: lightPrimaryText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: lightPrimaryText),
      ),
      textTheme: _lightTextTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: lightCardBorder, width: 1),
        ),
        color: lightCardBackground,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: GoogleFonts.inter().fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: darkAccentColor,
        onPrimary: Colors.black,
        surface: darkBackground,
        onSurface: darkPrimaryText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkPrimaryText,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          color: darkPrimaryText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: darkPrimaryText),
      ),
      textTheme: _darkTextTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkAccentColor,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: darkCardBorder, width: 1),
        ),
        color: darkCardBackground,
      ),
    );
  }

  static Color getPrimaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightPrimaryText
        : darkPrimaryText;
  }

  static Color getSecondaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightSecondaryText
        : darkSecondaryText;
  }

  static Color getCardBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightCardBorder
        : darkCardBorder;
  }

  static Color getCardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightCardBackground
        : darkCardBackground;
  }

  static Color getAccentTint(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightAccentTint
        : darkAccentTint;
  }
}