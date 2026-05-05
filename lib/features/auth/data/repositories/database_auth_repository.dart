import 'package:railway_secretariat/features/users/data/models/user_model.dart';
import 'package:railway_secretariat/core/services/database_service.dart';
import '../../domain/repositories/auth_repository.dart';

class DatabaseAuthRepository implements AuthRepository {
  final DatabaseService _databaseService;

  DatabaseAuthRepository({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService;

  @override
  Future<UserModel?> authenticate({
    required String username,
    required String password,
  }) {
    return _databaseService.authenticateUser(username, password);
  }

  @override
  Future<void> updatePassword({
    required int userId,
    required String newPassword,
    String? oldPassword,
  }) async {
    // [oldPassword] is intentionally ignored here — local-only deployments
    // are single-user, and [AuthUseCases.changePassword] already verifies
    // the old password against the live DB before this call. The parameter
    // exists on the interface for the remote (HTTP) implementation, where
    // the server enforces the same check.
    await _databaseService.updateUserPassword(userId, newPassword);
  }

  /// Local-only deployments do not have remote sessions to extend, so
  /// proactive refresh is a no-op. Returning `false` keeps the periodic
  /// timer in [AuthProvider] from firing repeatedly.
  @override
  Future<bool> refreshSession() async => false;
}
