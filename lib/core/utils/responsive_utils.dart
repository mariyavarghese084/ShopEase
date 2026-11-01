import 'package:flutter/material.dart';

/// Responsive breakpoints and layout helpers.
///
/// Used to build layouts that adapt to mobile, tablet, and web widths.
class ResponsiveUtils {
  ResponsiveUtils._();

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  /// Returns `true` when the current screen width is below [mobileBreakpoint].
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileBreakpoint;

  /// Returns `true` when the current screen width is between the mobile
  /// and tablet breakpoints.
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileBreakpoint && w < tabletBreakpoint;
  }

  /// Returns `true` when the current screen width is at or above
  /// [tabletBreakpoint].
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  /// Returns a value from [mobile], [tablet], or [desktop] depending on the
  /// current screen width.
  static T responsive<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  /// The maximum content width for centred layouts on wide screens.
  static const double maxContentWidth = 1200;
}
