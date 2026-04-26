import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:railway_secretariat/features/auth/data/repositories/encrypted_credentials_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EncryptedCredentialsRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    repo = EncryptedCredentialsRepository();
  });

  group('EncryptedCredentialsRepository', () {
    test('returns null when no credentials are saved', () async {
      final result = await repo.loadCredentials();
      expect(result, isNull);
    });

    test('saves and loads credentials correctly', () async {
      await repo.saveCredentials(username: 'admin', password: 'secret123');

      final loaded = await repo.loadCredentials();
      expect(loaded, isNotNull);
      expect(loaded!.username, 'admin');
      expect(loaded.password, 'secret123');
    });

    test('password is not stored in plaintext', () async {
      await repo.saveCredentials(username: 'admin', password: 'secret123');

      final prefs = await SharedPreferences.getInstance();
      // The encrypted password key should exist but NOT equal plaintext.
      final storedPassword = prefs.getString('enc_cred_password');
      expect(storedPassword, isNotNull);
      expect(storedPassword, isNot('secret123'));
    });

    test('each save generates a different salt (different ciphertext)', () async {
      await repo.saveCredentials(username: 'admin', password: 'secret123');
      final prefs1 = await SharedPreferences.getInstance();
      final cipher1 = prefs1.getString('enc_cred_password');
      final salt1 = prefs1.getString('enc_cred_salt');

      // Save again — new salt should produce different ciphertext.
      await repo.saveCredentials(username: 'admin', password: 'secret123');
      final prefs2 = await SharedPreferences.getInstance();
      final cipher2 = prefs2.getString('enc_cred_password');
      final salt2 = prefs2.getString('enc_cred_salt');

      // Salts should differ (with overwhelming probability).
      expect(salt1, isNot(salt2));
      // Ciphertexts should differ because salts differ.
      expect(cipher1, isNot(cipher2));
    });

    test('clearCredentials removes all keys', () async {
      await repo.saveCredentials(username: 'admin', password: 'secret123');
      await repo.clearCredentials();

      final loaded = await repo.loadCredentials();
      expect(loaded, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('enc_cred_username'), isNull);
      expect(prefs.getString('enc_cred_password'), isNull);
      expect(prefs.getString('enc_cred_salt'), isNull);
    });

    test('handles Unicode passwords (Arabic)', () async {
      await repo.saveCredentials(
        username: '\u0645\u062f\u064a\u0631',
        password: '\u0643\u0644\u0645\u0629_\u0633\u0631\u064a\u0629_123',
      );

      final loaded = await repo.loadCredentials();
      expect(loaded, isNotNull);
      expect(loaded!.username, '\u0645\u062f\u064a\u0631');
      expect(loaded.password, '\u0643\u0644\u0645\u0629_\u0633\u0631\u064a\u0629_123');
    });

    test('handles empty password', () async {
      await repo.saveCredentials(username: 'admin', password: '');

      final loaded = await repo.loadCredentials();
      expect(loaded, isNotNull);
      expect(loaded!.username, 'admin');
      expect(loaded.password, '');
    });

    test('handles very long password', () async {
      final longPassword = 'a' * 1000;
      await repo.saveCredentials(username: 'admin', password: longPassword);

      final loaded = await repo.loadCredentials();
      expect(loaded, isNotNull);
      expect(loaded!.password, longPassword);
    });

    group('legacy migration', () {
      test('migrates plaintext credentials to encrypted format', () async {
        // Simulate old plaintext storage.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'username': 'olduser',
          'password': 'oldpass',
        });
        repo = EncryptedCredentialsRepository();

        final loaded = await repo.loadCredentials();
        expect(loaded, isNotNull);
        expect(loaded!.username, 'olduser');
        expect(loaded.password, 'oldpass');

        // Legacy keys should be removed after migration.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('username'), isNull);
        expect(prefs.getString('password'), isNull);

        // Encrypted keys should now exist.
        expect(prefs.getString('enc_cred_username'), isNotNull);
        expect(prefs.getString('enc_cred_password'), isNotNull);
        expect(prefs.getString('enc_cred_salt'), isNotNull);
      });

      test('returns null when only legacy username exists (no password)', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'username': 'onlyuser',
        });
        repo = EncryptedCredentialsRepository();

        final loaded = await repo.loadCredentials();
        expect(loaded, isNull);
      });
    });

    test('overwriting credentials replaces old values', () async {
      await repo.saveCredentials(username: 'user1', password: 'pass1');
      await repo.saveCredentials(username: 'user2', password: 'pass2');

      final loaded = await repo.loadCredentials();
      expect(loaded, isNotNull);
      expect(loaded!.username, 'user2');
      expect(loaded.password, 'pass2');
    });
  });
}
