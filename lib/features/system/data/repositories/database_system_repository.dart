import 'package:railway_secretariat/core/services/database_service.dart';
import '../../domain/repositories/system_repository.dart';

class DatabaseSystemRepository implements SystemRepository {
  final DatabaseService _databaseService;

  DatabaseSystemRepository({required DatabaseService databaseService})
      : _databaseService = databaseService;

  @override
  Future<void> resetDatabaseConnection() {
    return _databaseService.resetConnection();
  }
}
