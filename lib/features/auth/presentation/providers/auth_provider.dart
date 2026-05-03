import 'dart:async';

import 'package:flutter/material.dart';

import 'package:railway_secretariat/core/network/api_client.dart';
import 'package:railway_secretariat/core/network/api_session.dart';
import 'package:railway_secretariat/features/auth/domain/usecases/auth_use_cases.dart';
import 'package:railway_secretariat/features/users/data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthUseCases _authUseCases;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  Timer? _errorTimer;

  /// Periodic timer that proactively refreshes the auth token long before
  /// the server-side TTL (8h) expires. Active only while a user is signed in.
  Timer? _refreshTimer;

  /// Interval between proactive refreshes. With an 8h server TTL this gives
  /// us ~16 chances per session, so a single transient network blip never
  /// pushes the user back to the login screen.
  static const Duration _refreshInterval = Duration(minutes: 30);

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';

  bool get canManageUsers => _currentUser?.canManageUsers ?? false;
  bool get canManageWarid => _currentUser?.canManageWarid ?? false;
  bool get canManageSadir => _currentUser?.canManageSadir ?? false;
  bool get canImportExcel => _currentUser?.canImportExcel ?? false;

  AuthProvider({required AuthUseCases authUseCases})
      : _authUseCases = authUseCases {
    _checkSavedLogin();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _refreshSessionSilently();
    });
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _refreshSessionSilently() async {
    if (_currentUser == null) {
      _stopRefreshTimer();
      return;
    }
    try {
      final ok = await _authUseCases.refreshSession();
      if (!ok) {
        // Token is no longer valid (expired or revoked). Stop the timer; the
        // ApiClient's `onUnauthorized` hook handles re-login transparently
        // when the user issues their next request.
        _stopRefreshTimer();
      }
    } catch (_) {
      // Network error: keep the timer alive so the next tick can retry. We
      // intentionally swallow the exception so it does not surface a UI
      // error banner (the user has not initiated any visible action).
    }
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
    try {
      final user = await _authUseCases.tryAutoLogin();
      if (user != null) {
        _currentUser = user;
        _startRefreshTimer();
        notifyListeners();
      }
    } catch (_) {
      // Ignore auto-login failures and keep app usable.
    }
  }

  Future<bool> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _setError(null);
    notifyListeners();

    try {
      final user = await _authUseCases
          .login(
            username: username,
            password: password,
            rememberMe: rememberMe,
          )
          .timeout(const Duration(seconds: 90));

      if (user != null) {
        _currentUser = user;
        _isLoading = false;
        _setError(null);
        _startRefreshTimer();
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
    } on ApiRequestException catch (e) {
      // Map the most common login failures to user-readable Arabic strings
      // instead of leaking minified runtime type names from the release
      // build (e.g. "minified:HJ").
      final String message;
      if (e.statusCode == 401 || e.statusCode == 403) {
        message = 'اسم المستخدم أو كلمة المرور غير صحيحة';
      } else if (e.statusCode == 429) {
        message = 'تم تجاوز عدد محاولات تسجيل الدخول. أعد المحاولة بعد دقيقة.';
      } else {
        message = 'حدث خطأ أثناء الاتصال بالسيرفر (${e.statusCode}).';
      }
      _setError(message, autoClear: const Duration(seconds: 8));
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
    _stopRefreshTimer();
    ApiSession.clear();
    await _authUseCases.logout();
    notifyListeners();
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final currentUser = _currentUser;
    if (currentUser == null) {
      return false;
    }

    _isLoading = true;
    _setError(null);
    notifyListeners();

    try {
      final success = await _authUseCases.changePassword(
        currentUser: currentUser,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (!success) {
        _setError(
          'كلمة المرور القديمة غير صحيحة',
          autoClear: const Duration(seconds: 6),
        );
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      _setError(null);
      notifyListeners();
      return true;
    } catch (_) {
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
    _refreshTimer?.cancel();
    super.dispose();
  }
}
