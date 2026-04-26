import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/theme_repository.dart';

class SharedPreferencesThemeRepository implements ThemeRepository {
  static const String _isDarkModeKey = 'isDarkMode';

  @override
  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_isDarkModeKey) ?? false;
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isDarkModeKey, mode == ThemeMode.dark);
  }
}
