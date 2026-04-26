import 'package:railway_secretariat/core/network/api_client.dart';
import 'package:railway_secretariat/features/users/data/models/user_model.dart';

import '../../domain/repositories/user_repository.dart';

class HttpUserRepository implements UserRepository {
  final ApiClient _apiClient;

  HttpUserRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<UserModel>> getAllUsers() async {
    final list = await _apiClient.getList('/api/users');
    return list
        .whereType<Map>()
        .map(
          (item) => UserModel.fromMap(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> insertUser(UserModel user) async {
    await _apiClient.postMap(
      '/api/users',
      body: <String, dynamic>{'user': user.toMap()},
    );
  }

  @override
  Future<void> updateUser(UserModel user, {String? newPassword}) async {
    final id = user.id;
    if (id == null) {
      throw StateError('User ID is required for update.');
    }

    await _apiClient.putMap(
      '/api/users/$id',
      body: <String, dynamic>{
        'user': user.toMap(),
        'newPassword': newPassword,
      },
    );
  }

  @override
  Future<void> deleteUser(int id) async {
    await _apiClient.delete('/api/users/$id');
  }
}
