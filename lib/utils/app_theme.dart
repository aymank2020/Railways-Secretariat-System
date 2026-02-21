import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color primaryLightColor = Color(0xFF5E92F3);
  static const Color primaryDarkColor = Color(0xFF003C8F);
  static const Color accentColor = Color(0xFFFF6F00);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color errorColor = Color(0xFFC62828);
  static const Color warningColor = Color(0xFFF9A825);
  static const Color infoColor = Color(0xFF0277BD);

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryColor,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      toolbarTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Color(0xB3FFFFFF),
      indicatorColor: Colors.white,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor:
          WidgetStatePropertyAll(primaryColor.withValues(alpha: 0.1)),
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.white,
      selectedIconTheme: IconThemeData(color: primaryColor),
      unselectedIconTheme: IconThemeData(color: Colors.black87),
      selectedLabelTextStyle: TextStyle(
        color: primaryColor,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
      bodySmall: TextStyle(fontSize: 12),
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryLightColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryLightColor,
      secondary: accentColor,
      surface: Color(0xFF1E1E1E),
      error: Color(0xFFEF5350),
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      toolbarTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 14,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Colors.white,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle:
          TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryLightColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF5350)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor:
          WidgetStatePropertyAll(primaryLightColor.withValues(alpha: 0.2)),
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: primaryLightColor,
      ),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF1E1E1E),
      selectedIconTheme: IconThemeData(color: primaryLightColor),
      unselectedIconTheme: IconThemeData(color: Colors.white70),
      selectedLabelTextStyle: TextStyle(
        color: primaryLightColor,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
