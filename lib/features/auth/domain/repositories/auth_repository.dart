import 'package:railway_secretariat/features/users/data/models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> authenticate({
    required String username,
    required String password,
  });

  Future<void> updatePassword({
    required int userId,
    required String newPassword,
  });
}
