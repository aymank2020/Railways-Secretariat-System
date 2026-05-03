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

  /// Refreshes the current authenticated session, extending its TTL.
  ///
  /// Returns `true` if the refresh succeeded, `false` if there is no live
  /// session (e.g. local-only mode, or the saved token is already expired).
  /// Network errors propagate so the caller can decide whether to retry.
  Future<bool> refreshSession() async => false;
}
