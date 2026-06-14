import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Blukios Design System — synchronized with web (fe-blue/src/assets/style.css)
/// Brand: "Blue" + "Kios" — Trusted digital marketplace
class AppTheme {
  // ─────────────────────────────────────────
  // BRAND PALETTE (Light Mode)
  // ─────────────────────────────────────────

  // Primary: Vibrant Blue — modern, trustworthy
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFFEFF6FF);

  // Secondary: Warm Amber — contrast accent for CTAs & highlights
  static const Color secondary = Color(0xFFF59E0B);
  static const Color secondaryDark = Color(0xFFD97706);

  // Neutral: Warm greys for text hierarchy
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  // Surfaces
  static const Color surface = Color(0xFFF9FAFB);
  static const Color cardWhite = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFFE5E7EB);
  static const Color stroke = Color(0xFFE5E7EB);

  // Semantic Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFEF4444);
  static const Color orange = Color(0xFFF59E0B);
  static const Color limeGreen = Color(0xFF84CC16);

  // Icon backgrounds
  static const Color iconBackground = Color(0xFFEFF6FF);

  // ─────────────────────────────────────────
  // DARK MODE PALETTE
  // ─────────────────────────────────────────

  static const Color darkPrimary = Color(0xFF60A5FA);
  static const Color darkSurface = Color(0xFF0A0A0A);
  static const Color darkCard = Color(0xFF171717);
  static const Color darkTextPrimary = Color(0xFFFAFAFA);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkBorder = Color(0x14FFFFFF); // 8% white
  static const Color darkMuted = Color(0xFF262626);
  static const Color darkIconBackground = Color(0xFF1E293B);
  static const Color darkAccent = Color(0xFF1E3A5F);

  // ─────────────────────────────────────────
  // DESIGN TOKENS (matches web CSS)
  // ─────────────────────────────────────────

  // Border Radius — synced with Tailwind classes
  static const double radiusFull = 9999.0;   // rounded-full (pill buttons)
  static const double radiusXL = 18.0;       // rounded-[18px] (inputs web)
  static const double radius2XL = 16.0;      // rounded-2xl (cards)
  static const double radiusXLCard = 12.0;   // rounded-xl (small cards)
  static const double radiusLG = 10.0;       // rounded-[10px] (sidebar items)

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 12.0;
  static const double spacingLG = 16.0;
  static const double spacingXL = 24.0;
  static const double spacingXXL = 32.0;

  // ─────────────────────────────────────────
  // GRADIENTS (matches web CSS)
  // ─────────────────────────────────────────

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
  );

  static const LinearGradient blukiosGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF60A5FA)],
    stops: [0.0, 0.6, 1.0],
  );

  // ─────────────────────────────────────────
  // LIGHT THEME
  // ─────────────────────────────────────────

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surface,
      onSurface: textPrimary,
      error: error,
    ),
    scaffoldBackgroundColor: surface,
    cardColor: cardWhite,
    dividerColor: border,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cardWhite,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(), // rounded-full (pill) like web
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: const BorderSide(color: border, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF9CA3AF),
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius2XL),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: primaryLight,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: primary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      shape: const StadiumBorder(),
      side: BorderSide.none,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: cardWhite,
      selectedItemColor: primary,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );

  // ─────────────────────────────────────────
  // DARK THEME
  // ─────────────────────────────────────────

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: darkPrimary,
      secondary: secondary,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      error: error,
    ),
    scaffoldBackgroundColor: darkSurface,
    cardColor: darkCard,
    dividerColor: darkBorder,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkCard,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: darkPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: darkTextPrimary,
        side: const BorderSide(color: darkBorder, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: darkPrimary,
        textStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        borderSide: const BorderSide(color: darkBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        borderSide: const BorderSide(color: darkPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusXL),
        borderSide: const BorderSide(color: error, width: 1.5),
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        color: const Color(0xFF71717A),
        fontWeight: FontWeight.w500,
      ),
    ),
    cardTheme: CardThemeData(
      color: darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius2XL),
        side: const BorderSide(color: darkBorder, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkAccent,
      labelStyle: GoogleFonts.plusJakartaSans(
        color: darkPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      shape: const StadiumBorder(),
      side: BorderSide.none,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkCard,
      selectedItemColor: darkPrimary,
      unselectedItemColor: darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
