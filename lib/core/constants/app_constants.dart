// ShopEase color palette and spacing constants
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Luxury Palette (derived directly from AÈRA luxury fragrance reference UI)
  static const Color luxuryWine = Color(0xFF8A4652);
  static const Color luxuryWineDark = Color(0xFF6E333E);
  static const Color luxuryWineLight = Color(0xFFF9EFF1);
  static const Color champagneGold = Color(0xFFC8A87D);
  static const Color champagneLight = Color(0xFFF5EFE6);
  static const Color blushIvory = Color(0xFFFAF5F0);
  static const Color softRose = Color(0xFFE8C5C8);

  // Core Theme Colors
  static const Color primaryOrange = Color(0xFF8A4652); // Luxury Wine primary
  static const Color primaryOrangeDark = Color(0xFF6E333E);
  static const Color background = Color(0xFFFAF5F0); // Soft blush ivory
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color beigeAccent = Color(0xFFC8A87D); // Champagne Gold
  static const Color mainText = Color(0xFF2C2224); // Deep luxury dark
  static const Color secondaryText = Color(0xFF8E8285); // Elegant muted text
  static const Color divider = Color(0xFFEFE8E3);
  static const Color surfaceVariant = Color(0xFFF3ECE6);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
}

/// Spacing constants (8-pt grid)
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

/// Border radius constants
class AppRadius {
  AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;
}

/// Application-wide string constants
class AppStrings {
  AppStrings._();

  static const String appName = 'ShopEase';
  static const String currency = '₹';
  static const String tagline = 'Luxury Cosmetics & Beauty.';
  static const String getStarted = 'Get Started';
  static const String welcomeTitle = 'Welcome to ShopEase';
  static const String welcomeSubtitle =
      'Discover high-performance luxury cosmetics\ncrafted to enhance your natural beauty.';
}
