import 'package:flutter/material.dart';

import 'package:railway_secretariat/features/theme/domain/usecases/theme_use_cases.dart';

class ThemeProvider extends ChangeNotifier {
  final ThemeUseCases _themeUseCases;

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider({required ThemeUseCases themeUseCases})
      : _themeUseCases = themeUseCases {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    _themeMode = await _themeUseCases.loadThemeMode();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;

    await _themeUseCases.saveThemeMode(_themeMode);

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    await _themeUseCases.saveThemeMode(mode);

    notifyListeners();
  }
}
