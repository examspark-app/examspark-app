import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Logo-inspired theme configuration — pink-orange gradient accent
class AppTheme {
  AppTheme._();

  // Logo-inspired accent — pink-orange gradient blend
  static const Color accentColor = Color(0xFFF0384C); // Pink-orange blend (primary)
  static const Color accentColorStart = Color(0xFFEC1E7F); // Gradient start — magenta/pink
  static const Color accentColorEnd = Color(0xFFFF9500); // Gradient end — orange

  // Universal Baby Pink — button click splash + light theme accent
  static const Color babyPink = Color(0xFFF48FB1);     // Material pink 300
  static const Color babyPinkBg = Color(0xFFFFF5F9);   // Soft baby pink bg (light mode)
  static const Color babyPinkMaroon = Color(0xFF4A1230); // Maroon text for baby pink theme

  static const Color lightBackground = Color(0xFFFAF9F7);
  static const Color lightPrimaryText = Color(0xFF1F1E1D);
  static const Color lightSecondaryText = Color(0xFF6B6862);
  static const Color lightCardBorder = Color(0xFFE8E6E1);
  static const Color lightCardBackground = Color(0xFFFFFFFF);
  static const Color lightAccentTint = Color(0x14F0384C); // Soft pink-orange tint

  // Dark mode — Claude.ai style near-black
  static const Color darkBackground = Color(0xFF0F0F0F);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFFB3B3B3);
  static const Color darkCardBorder = Color(0xFF2A2A2E);
  static const Color darkCardBackground = Color(0xFF1A1A1D);
  static const Color darkInputBackground = Color(0xFF1C1C1F);
  static const Color darkAccentTint = Color(0x33FFFFFF); // White icon-box background

  // Dark mode accent (buttons) — violet (Claude-like purple accent)
  static const Color darkAccentColor = Color(0xFF5137ED);

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

  static const List<String> fontFallback = [
    'Noto Sans Bengali',
    'Hind Siliguri',
    'Noto Sans Devanagari',
    'Roboto',
    'sans-serif',
  ];

  static TextTheme get _lightTextTheme => GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: lightPrimaryText,
            height: 1.3,
            letterSpacing: -0.5,
            fontFamilyFallback: fontFallback,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: lightPrimaryText,
            height: 1.65,
            fontFamilyFallback: fontFallback,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: lightPrimaryText,
            height: 1.6,
            fontFamilyFallback: fontFallback,
          ),
          bodySmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: lightSecondaryText,
            height: 1.5,
            fontFamilyFallback: fontFallback,
          ),
          labelMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            fontFamilyFallback: fontFallback,
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
            fontFamilyFallback: fontFallback,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: darkPrimaryText,
            height: 1.65,
            fontFamilyFallback: fontFallback,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: darkPrimaryText,
            height: 1.6,
            fontFamilyFallback: fontFallback,
          ),
          bodySmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: darkSecondaryText,
            height: 1.5,
            fontFamilyFallback: fontFallback,
          ),
          labelMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: darkPrimaryText,
            fontFamilyFallback: fontFallback,
          ),
        ),
      );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      fontFamily: GoogleFonts.inter().fontFamily,
      fontFamilyFallback: fontFallback,
      splashColor: babyPink.withValues(alpha: 0.3),
      highlightColor: babyPink.withValues(alpha: 0.18),
      colorScheme: ColorScheme.light(
        primary: babyPink,
        onPrimary: babyPinkMaroon,
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
          backgroundColor: babyPink,
          foregroundColor: babyPinkMaroon,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: babyPink,
          foregroundColor: babyPinkMaroon,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
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
      fontFamilyFallback: fontFallback,
      splashColor: babyPink.withValues(alpha: 0.35),
      highlightColor: babyPink.withValues(alpha: 0.2),
      colorScheme: ColorScheme.dark(
        primary: darkAccentColor,
        onPrimary: Colors.white,
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkAccentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
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

  static Color getInputBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? lightCardBackground
        : darkInputBackground;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? null
              : (isDark
                  ? const LinearGradient(
                      colors: [Color(0xFF6C4EFF), Color(0xFF5137ED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : AppTheme.accentGradient),
          color: onPressed == null ? Colors.grey.shade400 : null,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: InkWell(
          onTap: onPressed,
          splashColor: AppTheme.babyPink.withValues(alpha: 0.35),
          highlightColor: AppTheme.babyPink.withValues(alpha: 0.2),
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
