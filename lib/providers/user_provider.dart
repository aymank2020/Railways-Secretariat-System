import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/database_service.dart';

class UserProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _users = await _db.getAllUsers();
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
      await _db.insertUser(user);
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
      await _db.updateUser(user, newPassword: newPassword);
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
      await _db.deleteUser(id);
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

