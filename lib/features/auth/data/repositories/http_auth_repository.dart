import 'package:railway_secretariat/core/network/api_client.dart';
import 'package:railway_secretariat/core/network/api_session.dart';
import 'package:railway_secretariat/features/users/data/models/user_model.dart';

import '../../domain/repositories/auth_repository.dart';

class HttpAuthRepository implements AuthRepository {
  final ApiClient _apiClient;

  HttpAuthRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<UserModel?> authenticate({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.postMap(
      '/api/auth/login',
      body: <String, dynamic>{
        'username': username,
        'password': password,
      },
    );

    final token = response['token']?.toString();
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    ApiSession.setToken(token);

    final rawUser = response['user'];
    if (rawUser is Map<String, dynamic>) {
      return UserModel.fromMap(rawUser);
    }
    if (rawUser is Map) {
      return UserModel.fromMap(
        rawUser.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  @override
  Future<void> updatePassword({
    required int userId,
    required String newPassword,
  }) async {
    await _apiClient.postMap(
      '/api/auth/change-password',
      body: <String, dynamic>{
        'userId': userId,
        'newPassword': newPassword,
      },
    );
  }
}
