import 'package:railway_secretariat/core/network/api_client.dart';

import '../../domain/repositories/system_repository.dart';

class HttpSystemRepository implements SystemRepository {
  final ApiClient _apiClient;

  HttpSystemRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<void> resetDatabaseConnection() async {
    await _apiClient.postMap('/api/system/reset-db');
  }
}
