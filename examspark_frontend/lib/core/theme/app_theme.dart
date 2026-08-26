import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Logo-inspired theme configuration — pink-orange gradient accent
class AppTheme {
  AppTheme._();

  // Logo-inspired accent — pink-orange gradient blend
  static const Color accentColor = Color(0xFFF0384C); // Pink-orange blend (primary)
  static const Color accentColorStart = Color(0xFFEC1E7F); // Gradient start — magenta/pink
  static const Color accentColorEnd = Color(0xFFFF9500); // Gradient end — orange

  static const Color lightBackground = Color(0xFFFAF9F7);
  static const Color lightPrimaryText = Color(0xFF1F1E1D);
  static const Color lightSecondaryText = Color(0xFF6B6862);
  static const Color lightCardBorder = Color(0xFFE8E6E1);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightAccentTint = Color(0x14F0384C); // Soft pink-orange tint

  static const Color darkBackground = Color(0xFF201F1E);
  static const Color darkPrimaryText = Color(0xFFF2F0EB);
  static const Color darkSecondaryText = Color(0xFFB0ACA3);
  static const Color darkCardBorder = Color(0xFF3D3B37);
  static const Color darkCardBackground = Color(0xFF2C2B29);
  static const Color darkAccentTint = Color(0xFFFFFFFF); // White icon-box background

  // Dark mode accent (buttons) — brighter pink-orange for visibility on dark bg
  static const Color darkAccentColor = Color(0xFFFF5C7A);

  // GlowGuide (Skin Care AI) feature accent — purple, kept separate from
  // the app's main pink-orange accent since GlowGuide has its own
  // black & white + purple visual identity.
  static const Color glowGuidePurple = Color(0xFF7C4DFF);
  static const Color glowGuidePurpleLighter = Color(0xFF9D75FF); // ~15% lighter for gradient

  // GlowGuide chat screen — baby-pink accent (same in light & dark mode)
  static const Color glowGuidePink = Color(0xFFF48FB1);       // Material pink 300
  static const Color glowGuidePinkLight = Color(0xFFF8BBD0);  // Material pink 200

  // Logo gradient — use for primary CTA buttons via BoxDecoration
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accentColorStart, accentColorEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

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
            height: 1.65,
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
            height: 1.65,
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

/// Gradient CTA button — drop-in replacement for ElevatedButton wherever
/// you want the logo-style pink-orange gradient instead of solid color.
///
/// Usage:
///   GradientButton(
///     onPressed: () {},
///     child: const Text('Get Teacher Plan'),
///   )
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.borderRadius,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppTheme.borderRadius;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        decoration: BoxDecoration(
          gradient: onPressed == null ? null : AppTheme.accentGradient,
          color: onPressed == null ? Colors.grey.shade400 : null,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding,
            child: DefaultTextStyle(
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              child: IconTheme(
                data: const IconThemeData(color: Colors.white),
                child: Center(widthFactor: 1, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}