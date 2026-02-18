import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  Timer? _errorTimer;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';

  bool get canManageUsers => _currentUser?.canManageUsers ?? false;
  bool get canManageWarid => _currentUser?.canManageWarid ?? false;
  bool get canManageSadir => _currentUser?.canManageSadir ?? false;
  bool get canImportExcel => _currentUser?.canImportExcel ?? false;

  AuthProvider() {
    _checkSavedLogin();
  }

  void _setError(String? message, {Duration? autoClear}) {
    _errorTimer?.cancel();
    _error = message;

    if (message != null && autoClear != null) {
      _errorTimer = Timer(autoClear, () {
        if (_error == message) {
          _error = null;
          notifyListeners();
        }
      });
    }
  }

  Future<void> _checkSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    final savedPassword = prefs.getString('password');

    if (savedUsername != null && savedPassword != null) {
      final success =
          await login(savedUsername, savedPassword, rememberMe: true);
      if (!success) {
        await prefs.remove('username');
        await prefs.remove('password');
      }
    }
  }

  Future<bool> login(String username, String password,
      {bool rememberMe = false}) async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _setError(null);
    notifyListeners();

    try {
      final user = await _db
          .authenticateUser(username.trim(), password)
          .timeout(const Duration(seconds: 90));

      if (user != null) {
        _currentUser = user;

        final prefs = await SharedPreferences.getInstance();
        if (rememberMe) {
          await prefs.setString('username', username.trim());
          await prefs.setString('password', password);
        } else {
          await prefs.remove('username');
          await prefs.remove('password');
        }

        _isLoading = false;
        _setError(null);
        notifyListeners();
        return true;
      }

      _setError(
        'اسم المستخدم أو كلمة المرور غير صحيحة',
        autoClear: const Duration(seconds: 6),
      );
      _isLoading = false;
      notifyListeners();
      return false;
    } on TimeoutException {
      _setError(
        'انتهت مهلة تسجيل الدخول. أعد المحاولة مرة أخرى.',
        autoClear: const Duration(seconds: 8),
      );
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _setError(
        'حدث خطأ أثناء تسجيل الدخول: ${e.runtimeType}',
        autoClear: const Duration(seconds: 8),
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _setError(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');

    notifyListeners();
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_currentUser == null) {
      return false;
    }

    _isLoading = true;
    _setError(null);
    notifyListeners();

    try {
      final user =
          await _db.authenticateUser(_currentUser!.username, oldPassword);

      if (user == null) {
        _setError(
          'كلمة المرور القديمة غير صحيحة',
          autoClear: const Duration(seconds: 6),
        );
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _db.updateUserPassword(_currentUser!.id!, newPassword);
      _isLoading = false;
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(
        'حدث خطأ أثناء تغيير كلمة المرور',
        autoClear: const Duration(seconds: 8),
      );
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _setError(null);
    notifyListeners();
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }
}

