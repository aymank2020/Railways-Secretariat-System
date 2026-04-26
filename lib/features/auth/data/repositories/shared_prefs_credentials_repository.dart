import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/credentials_repository.dart';

class SharedPreferencesCredentialsRepository implements CredentialsRepository {
  static const String _usernameKey = 'username';
  static const String _passwordKey = 'password';

  @override
  Future<SavedCredentials?> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey);
    final password = prefs.getString(_passwordKey);

    if (username == null || password == null) {
      return null;
    }

    return SavedCredentials(username: username, password: password);
  }

  @override
  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_passwordKey, password);
  }

  @override
  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
  }
}
