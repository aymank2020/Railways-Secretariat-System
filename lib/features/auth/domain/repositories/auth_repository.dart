import 'package:railway_secretariat/features/users/data/models/user_model.dart';

abstract class AuthRepository {
  Future<UserModel?> authenticate({
    required String username,
    required String password,
  });

  /// Updates a user's password.
  ///
  /// [oldPassword] is required for self-change (i.e. the caller is changing
  /// their own password) so that a stolen session token cannot rotate the
  /// password without knowing the current one. Pass `null` only for an
  /// admin reset of someone else's password — the server enforces that the
  /// caller is an admin AND the target user differs from the caller in
  /// that case.
  Future<void> updatePassword({
    required int userId,
    required String newPassword,
    String? oldPassword,
  });

  /// Refreshes the current authenticated session, extending its TTL.
  ///
  /// Returns `true` if the refresh succeeded, `false` if there is no live
  /// session (e.g. local-only mode, or the saved token is already expired).
  /// Network errors propagate so the caller can decide whether to retry.
  Future<bool> refreshSession() async => false;
}
