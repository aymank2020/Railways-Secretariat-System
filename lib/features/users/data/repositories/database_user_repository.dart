import 'package:railway_secretariat/features/users/data/models/user_model.dart';
import 'package:railway_secretariat/core/services/database_service.dart';
import '../../domain/repositories/user_repository.dart';

class DatabaseUserRepository implements UserRepository {
  final DatabaseService _databaseService;

  DatabaseUserRepository({required DatabaseService databaseService})
      : _databaseService = databaseService;

  @override
  Future<List<UserModel>> getAllUsers() {
    return _databaseService.getAllUsers();
  }

  @override
  Future<void> insertUser(UserModel user) async {
    await _databaseService.insertUser(user);
  }

  @override
  Future<void> updateUser(UserModel user, {String? newPassword}) async {
    await _databaseService.updateUser(user, newPassword: newPassword);
  }

  @override
  Future<void> deleteUser(int id) async {
    await _databaseService.deleteUser(id);
  }
}
