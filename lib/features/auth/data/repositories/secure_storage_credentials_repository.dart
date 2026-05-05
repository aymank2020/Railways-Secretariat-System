import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/credentials_repository.dart';
import 'encrypted_credentials_repository.dart';

/// Credentials repository backed by [flutter_secure_storage].
///
/// Replaces [EncryptedCredentialsRepository], which encrypted the
/// password with a hard-coded XOR key (the "key" lived in plain text
/// in the application binary, so anyone with read access to the
/// installed app could trivially decrypt the saved password). The new
/// implementation hands the secret to the platform's secure-storage
/// API instead:
///
///   * iOS / macOS — Keychain (per-app entitlement).
///   * Android      — Keystore-encrypted SharedPreferences.
///   * Windows      — DPAPI (per-user master key).
///   * Linux        — libsecret (gnome-keyring / kwallet).
///   * Web          — AES-GCM in IndexedDB with a key in IndexedDB
///                    (still browser-bound, no application secret in
///                    the deployed JS bundle).
///
/// On the first call after upgrading, [loadCredentials] transparently
/// migrates any value that was sitting in the legacy XOR-encrypted
/// SharedPreferences entries (or the even older plaintext entries),
/// re-saves it through the secure backend, and wipes the legacy keys.
/// Users do not have to log in again as part of the upgrade.
class SecureStorageCredentialsRepository implements CredentialsRepository {
  static const String _usernameKey = 'sec_cred_username';
  static const String _passwordKey = 'sec_cred_password';

  final FlutterSecureStorage _storage;

  // Lazy because a fresh instance can race with the legacy migration on
  // the first cold start; isolating one [EncryptedCredentialsRepository]
  // ensures both sides see the same SharedPreferences view.
  final EncryptedCredentialsRepository _legacy;

  SecureStorageCredentialsRepository({
    FlutterSecureStorage? storage,
    EncryptedCredentialsRepository? legacy,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _legacy = legacy ?? EncryptedCredentialsRepository();

  @override
  Future<SavedCredentials?> loadCredentials() async {
    try {
      final username = await _storage.read(key: _usernameKey);
      final password = await _storage.read(key: _passwordKey);
      if (username != null && password != null) {
        return SavedCredentials(username: username, password: password);
      }
    } catch (_) {
      // Treat any platform error (locked keychain, missing libsecret,
      // etc.) as "no saved credentials" — the user just signs in
      // again, never crash the auto-login path.
      return null;
    }

    // No secure-storage entry yet — see if the legacy XOR-encrypted
    // SharedPreferences holds something we should migrate forward.
    final legacy = await _legacy.loadCredentials();
    if (legacy == null) {
      return null;
    }

    try {
      await _storage.write(key: _usernameKey, value: legacy.username);
      await _storage.write(key: _passwordKey, value: legacy.password);
      // Wipe the SharedPreferences copy so the password never sits in
      // both stores after the migration succeeds.
      await _legacy.clearCredentials();
      // Belt-and-braces: clear every legacy key we know of, in case
      // the implementation evolves.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('username');
      await prefs.remove('password');
    } catch (_) {
      // If we couldn't move the secret over, leave it where it is —
      // the legacy repository will still serve it on the next call.
    }
    return legacy;
  }

  @override
  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
    // Clear any leftover legacy entries so the saved password lives in
    // exactly one place going forward.
    try {
      await _legacy.clearCredentials();
    } catch (_) {}
  }

  @override
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _usernameKey);
      await _storage.delete(key: _passwordKey);
    } catch (_) {}
    try {
      await _legacy.clearCredentials();
    } catch (_) {}
  }
}
