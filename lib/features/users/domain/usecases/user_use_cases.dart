import 'package:railway_secretariat/features/users/data/models/user_model.dart';
import '../repositories/user_repository.dart';

class UserUseCases {
  final UserRepository _repository;

  UserUseCases({required UserRepository repository}) : _repository = repository;

  Future<List<UserModel>> getAllUsers() {
    return _repository.getAllUsers();
  }

  Future<void> insertUser(UserModel user) {
    return _repository.insertUser(user);
  }

  Future<void> updateUser(UserModel user, {String? newPassword}) {
    return _repository.updateUser(user, newPassword: newPassword);
  }

  Future<void> deleteUser(int id) {
    return _repository.deleteUser(id);
  }
}
