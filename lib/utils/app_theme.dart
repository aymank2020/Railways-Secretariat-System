import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF00A7E1);
  static const Color primaryLightColor = Color(0xFF7AE7FF);
  static const Color primaryDarkColor = Color(0xFF004D78);
  static const Color accentColor = Color(0xFF00D7A4);
  static const Color successColor = Color(0xFF00C58A);
  static const Color errorColor = Color(0xFFD6456A);
  static const Color warningColor = Color(0xFFFFB74D);
  static const Color infoColor = Color(0xFF64B5F6);

  static const Color _lightBackground = Color(0xFFF2F8FF);
  static const Color _lightSurface = Colors.white;
  static const Color _darkBackground = Color(0xFF060F1C);
  static const Color _darkSurface = Color(0xFF111D2D);

  static const LinearGradient loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF061634),
      Color(0xFF0E2D5E),
      Color(0xFF005F84),
    ],
  );

  static ThemeData _baseTheme(ColorScheme scheme, {required bool isDark}) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : primaryColor.withValues(alpha: 0.20);
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : primaryColor.withValues(alpha: 0.04);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: scheme.primary,
      colorScheme: scheme,
      // Bundled in pubspec.yaml under assets/fonts/. Setting it here means
      // every text widget uses the local font instead of triggering Flutter
      // Web's runtime fetch from fonts.gstatic.com, which the CSP blocks.
      fontFamily: 'NotoSansArabic',
      scaffoldBackgroundColor: isDark ? _darkBackground : _lightBackground,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor:
            isDark ? _darkSurface.withValues(alpha: 0.95) : _lightSurface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? _darkSurface : _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor:
            isDark ? _darkSurface.withValues(alpha: 0.95) : _lightSurface,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(
          color: isDark ? Colors.white70 : Colors.black87,
        ),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor:
            WidgetStatePropertyAll(scheme.primary.withValues(alpha: 0.12)),
        headingTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? _darkSurface : Colors.black87,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.65),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }

  static final ThemeData lightTheme = _baseTheme(
    const ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      onSecondary: Colors.white,
      tertiary: infoColor,
      error: errorColor,
      onSurface: Color(0xFF0C1B2C),
    ),
    isDark: false,
  );

  static final ThemeData darkTheme = _baseTheme(
    const ColorScheme.dark(
      primary: primaryLightColor,
      onPrimary: Color(0xFF002533),
      secondary: accentColor,
      onSecondary: Color(0xFF003322),
      tertiary: Color(0xFF74C0FC),
      error: Color(0xFFFF8DA1),
      surface: _darkSurface,
      onSurface: Color(0xFFE7F2FF),
    ),
    isDark: true,
  );
}
