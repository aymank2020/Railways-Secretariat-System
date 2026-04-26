class SavedCredentials {
  final String username;
  final String password;

  const SavedCredentials({
    required this.username,
    required this.password,
  });
}

abstract class CredentialsRepository {
  Future<SavedCredentials?> loadCredentials();

  Future<void> saveCredentials({
    required String username,
    required String password,
  });

  Future<void> clearCredentials();
}
