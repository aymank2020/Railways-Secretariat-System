import '../repositories/system_repository.dart';

class SystemUseCases {
  final SystemRepository _repository;

  SystemUseCases({required SystemRepository repository})
      : _repository = repository;

  Future<void> resetDatabaseConnection() {
    return _repository.resetDatabaseConnection();
  }
}
