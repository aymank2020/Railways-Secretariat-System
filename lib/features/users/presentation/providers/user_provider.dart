import 'package:flutter/material.dart';

import 'package:railway_secretariat/features/users/domain/usecases/user_use_cases.dart';
import 'package:railway_secretariat/features/users/data/models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final UserUseCases _userUseCases;

  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  UserProvider({required UserUseCases userUseCases})
      : _userUseCases = userUseCases;

  Future<void> loadUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _users = await _userUseCases.getAllUsers();
      _error = null;
    } catch (e) {
      _error = 'حدث خطأ أثناء تحميل المستخدمين: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addUser(UserModel user) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _userUseCases.insertUser(user);
      await loadUsers();
      _error = null;
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء إضافة المستخدم: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser(UserModel user, {String? newPassword}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _userUseCases.updateUser(user, newPassword: newPassword);
      await loadUsers();
      _error = null;
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء تحديث المستخدم: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _userUseCases.deleteUser(id);
      await loadUsers();
      _error = null;
      return true;
    } catch (e) {
      _error = 'حدث خطأ أثناء حذف المستخدم: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
