import 'package:flutter/material.dart';

import '../repositories/theme_repository.dart';

class ThemeUseCases {
  final ThemeRepository _repository;

  ThemeUseCases({required ThemeRepository repository})
      : _repository = repository;

  Future<ThemeMode> loadThemeMode() {
    return _repository.loadThemeMode();
  }

  Future<void> saveThemeMode(ThemeMode mode) {
    return _repository.saveThemeMode(mode);
  }
}
