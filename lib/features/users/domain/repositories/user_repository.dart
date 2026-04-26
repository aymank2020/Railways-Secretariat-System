import 'package:railway_secretariat/features/users/data/models/user_model.dart';

abstract class UserRepository {
  Future<List<UserModel>> getAllUsers();

  Future<void> insertUser(UserModel user);

  Future<void> updateUser(UserModel user, {String? newPassword});

  Future<void> deleteUser(int id);
}
