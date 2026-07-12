import 'package:flutter/material.dart';

/// Central breakpoints for ExamSpark responsive layout.
///
/// Mobile: bottom nav, bottom sheets.
/// Desktop: side nav rail, split panels.
class Responsive {
  Responsive._();

  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 900;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < tabletBreakpoint;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tabletBreakpoint && width < desktopBreakpoint;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  /// True when the layout should use a side nav rail instead of a bottom bar.
  static bool useSideNav(BuildContext context) => isDesktop(context);

  /// Max content width for centered readable columns on large screens.
  static double contentMaxWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktopBreakpoint) return 880;
    return width;
  }
}
