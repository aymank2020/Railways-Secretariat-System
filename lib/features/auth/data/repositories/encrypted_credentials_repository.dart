import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/credentials_repository.dart';

/// A credentials repository that encrypts the stored password using
/// a device-specific key derived from a random salt stored alongside.
///
/// This is significantly better than plaintext SharedPreferences while
/// avoiding the need for platform-specific native plugins. The encryption
/// is a simple XOR cipher keyed by a HMAC-SHA256 derived key. It won't
/// stop a sophisticated attacker with device access, but it prevents
/// casual inspection and accidental exposure.
class EncryptedCredentialsRepository implements CredentialsRepository {
  static const String _usernameKey = 'enc_cred_username';
  static const String _passwordKey = 'enc_cred_password';
  static const String _saltKey = 'enc_cred_salt';

  // A fixed application-level secret mixed into the key derivation.
  // This is not a secret per se (it's in the source), but it adds
  // an extra layer so that the stored ciphertext is not trivially
  // reversible without knowing this value.
  static const String _appSecret = 'RailwaySecretariat_v1_CredKey';

  @override
  Future<SavedCredentials?> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey);
    final encryptedPassword = prefs.getString(_passwordKey);
    final salt = prefs.getString(_saltKey);

    if (username == null || encryptedPassword == null || salt == null) {
      // Try to migrate from old plaintext storage.
      return _tryMigrateLegacy(prefs);
    }

    try {
      final password = _decrypt(encryptedPassword, salt);
      return SavedCredentials(username: username, password: password);
    } catch (_) {
      // Corrupted data — clear and return null.
      await _clear(prefs);
      return null;
    }
  }

  @override
  Future<void> saveCredentials({
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final encrypted = _encrypt(password, salt);

    await prefs.setString(_usernameKey, username);
    await prefs.setString(_passwordKey, encrypted);
    await prefs.setString(_saltKey, salt);

    // Remove legacy plaintext keys if they exist.
    await prefs.remove('username');
    await prefs.remove('password');
  }

  @override
  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await _clear(prefs);
    // Also clear legacy keys.
    await prefs.remove('username');
    await prefs.remove('password');
  }

  /// Try to migrate from the old plaintext SharedPreferencesCredentialsRepository.
  Future<SavedCredentials?> _tryMigrateLegacy(SharedPreferences prefs) async {
    final legacyUsername = prefs.getString('username');
    final legacyPassword = prefs.getString('password');

    if (legacyUsername == null || legacyPassword == null) {
      return null;
    }

    // Re-save with encryption.
    await saveCredentials(
      username: legacyUsername,
      password: legacyPassword,
    );

    return SavedCredentials(
      username: legacyUsername,
      password: legacyPassword,
    );
  }

  Future<void> _clear(SharedPreferences prefs) async {
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_saltKey);
  }

  // ---------------------------------------------------------------------------
  // Encryption helpers
  // ---------------------------------------------------------------------------

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Derive a key from the salt and app secret using HMAC-SHA256.
  List<int> _deriveKey(String salt) {
    final hmac = Hmac(sha256, utf8.encode(_appSecret));
    final digest = hmac.convert(utf8.encode(salt));
    return digest.bytes;
  }

  /// Encrypt [plaintext] with a key derived from [salt].
  /// Uses XOR cipher with the derived key (repeating as needed).
  String _encrypt(String plaintext, String salt) {
    final key = _deriveKey(salt);
    final inputBytes = utf8.encode(plaintext);
    final outputBytes = Uint8List(inputBytes.length);

    for (var i = 0; i < inputBytes.length; i++) {
      outputBytes[i] = inputBytes[i] ^ key[i % key.length];
    }

    return base64Encode(outputBytes);
  }

  /// Decrypt [ciphertext] with a key derived from [salt].
  String _decrypt(String ciphertext, String salt) {
    final key = _deriveKey(salt);
    final inputBytes = base64Decode(ciphertext);
    final outputBytes = Uint8List(inputBytes.length);

    for (var i = 0; i < inputBytes.length; i++) {
      outputBytes[i] = inputBytes[i] ^ key[i % key.length];
    }

    return utf8.decode(outputBytes);
  }
}
