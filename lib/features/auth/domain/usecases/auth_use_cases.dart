import 'package:railway_secretariat/features/users/data/models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/credentials_repository.dart';

class AuthUseCases {
  final AuthRepository _authRepository;
  final CredentialsRepository _credentialsRepository;

  AuthUseCases({
    required AuthRepository authRepository,
    required CredentialsRepository credentialsRepository,
  })  : _authRepository = authRepository,
        _credentialsRepository = credentialsRepository;

  Future<UserModel?> tryAutoLogin() async {
    final saved = await _credentialsRepository.loadCredentials();
    if (saved == null) {
      return null;
    }

    final user = await _authRepository.authenticate(
      username: saved.username,
      password: saved.password,
    );

    if (user == null) {
      await _credentialsRepository.clearCredentials();
    }

    return user;
  }

  Future<UserModel?> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final normalizedUsername = username.trim();
    final user = await _authRepository.authenticate(
      username: normalizedUsername,
      password: password,
    );

    if (user == null) {
      return null;
    }

    if (rememberMe) {
      await _credentialsRepository.saveCredentials(
        username: normalizedUsername,
        password: password,
      );
    } else {
      await _credentialsRepository.clearCredentials();
    }

    return user;
  }

  Future<void> logout() {
    return _credentialsRepository.clearCredentials();
  }

  Future<bool> changePassword({
    required UserModel currentUser,
    required String oldPassword,
    required String newPassword,
  }) async {
    final userId = currentUser.id;
    if (userId == null) {
      return false;
    }

    final user = await _authRepository.authenticate(
      username: currentUser.username,
      password: oldPassword,
    );
    if (user == null) {
      return false;
    }

    await _authRepository.updatePassword(
      userId: userId,
      newPassword: newPassword,
    );
    return true;
  }
}
