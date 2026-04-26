import 'dart:io';

import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:railway_secretariat/server/helpers.dart';
import 'package:railway_secretariat/server/middleware.dart';
import 'package:railway_secretariat/server/session_store.dart';

void main() {
  // Initialize sqflite FFI for desktop test runner.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // ---------------------------------------------------------------------------
  // helpers.dart
  // ---------------------------------------------------------------------------

  group('helpers - parseDate', () {
    test('parses valid ISO 8601 date', () {
      expect(parseDate('2024-03-15'), DateTime(2024, 3, 15));
    });

    test('returns null for null input', () {
      expect(parseDate(null), isNull);
    });

    test('returns null for empty string', () {
      expect(parseDate(''), isNull);
      expect(parseDate('   '), isNull);
    });

    test('returns null for invalid date', () {
      expect(parseDate('not-a-date'), isNull);
    });
  });

  group('helpers - parseInt', () {
    test('parses valid integer', () {
      expect(parseInt('42'), 42);
    });

    test('returns null for null input', () {
      expect(parseInt(null), isNull);
    });

    test('returns null for empty string', () {
      expect(parseInt(''), isNull);
    });

    test('returns null for non-numeric string', () {
      expect(parseInt('abc'), isNull);
    });

    test('handles negative numbers', () {
      expect(parseInt('-5'), -5);
    });
  });

  group('helpers - parseBool', () {
    test('returns true for bool true', () {
      expect(parseBool(true), isTrue);
    });

    test('returns false for bool false', () {
      expect(parseBool(false), isFalse);
    });

    test('returns true for string "1"', () {
      expect(parseBool('1'), isTrue);
    });

    test('returns true for string "true"', () {
      expect(parseBool('true'), isTrue);
      expect(parseBool('TRUE'), isTrue);
      expect(parseBool('True'), isTrue);
    });

    test('returns true for string "yes"', () {
      expect(parseBool('yes'), isTrue);
    });

    test('returns false for string "0"', () {
      expect(parseBool('0'), isFalse);
    });

    test('returns false for string "false"', () {
      expect(parseBool('false'), isFalse);
    });

    test('returns false for null', () {
      expect(parseBool(null), isFalse);
    });

    test('returns false for empty string', () {
      expect(parseBool(''), isFalse);
    });
  });

  group('helpers - decodeBase64', () {
    test('decodes valid base64', () {
      final result = decodeBase64('SGVsbG8='); // "Hello"
      expect(String.fromCharCodes(result), 'Hello');
    });

    test('throws ApiException for empty input', () {
      expect(
        () => decodeBase64(''),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          HttpStatus.badRequest,
        )),
      );
    });

    test('throws ApiException for invalid base64', () {
      expect(
        () => decodeBase64('!!!not-base64!!!'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('helpers - ensureMap', () {
    test('returns Map<String, dynamic> as-is', () {
      final input = <String, dynamic>{'key': 'value'};
      expect(ensureMap(input, fieldName: 'test'), input);
    });

    test('converts Map<dynamic, dynamic> to Map<String, dynamic>', () {
      final input = <dynamic, dynamic>{1: 'a', 'key': 'b'};
      final result = ensureMap(input, fieldName: 'test');
      expect(result, isA<Map<String, dynamic>>());
      expect(result['1'], 'a');
      expect(result['key'], 'b');
    });

    test('throws ApiException for non-map input', () {
      expect(
        () => ensureMap('not a map', fieldName: 'data'),
        throwsA(isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('data'),
        )),
      );
    });
  });

  group('helpers - ApiException', () {
    test('stores statusCode and message', () {
      const e = ApiException(404, 'Not found');
      expect(e.statusCode, 404);
      expect(e.message, 'Not found');
    });
  });

  group('helpers - permission checks', () {
    test('requireUsersPermission passes for admin', () {
      final session = ServerSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: false,
        canManageWarid: false,
        canManageSadir: false,
        canImportExcel: false,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(() => requireUsersPermission(session), returnsNormally);
    });

    test('requireUsersPermission passes for user with canManageUsers', () {
      final session = ServerSession(
        userId: 2,
        username: 'user',
        role: 'user',
        canManageUsers: true,
        canManageWarid: false,
        canManageSadir: false,
        canImportExcel: false,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(() => requireUsersPermission(session), returnsNormally);
    });

    test('requireUsersPermission throws for unprivileged user', () {
      final session = ServerSession(
        userId: 3,
        username: 'viewer',
        role: 'viewer',
        canManageUsers: false,
        canManageWarid: false,
        canManageSadir: false,
        canImportExcel: false,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(
        () => requireUsersPermission(session),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          HttpStatus.forbidden,
        )),
      );
    });

    test('requireWaridPermission passes for admin', () {
      final session = ServerSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: false,
        canManageWarid: false,
        canManageSadir: false,
        canImportExcel: false,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(() => requireWaridPermission(session), returnsNormally);
    });

    test('requireWaridPermission throws for unprivileged user', () {
      final session = ServerSession(
        userId: 3,
        username: 'viewer',
        role: 'viewer',
        canManageUsers: false,
        canManageWarid: false,
        canManageSadir: false,
        canImportExcel: false,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(
        () => requireWaridPermission(session),
        throwsA(isA<ApiException>()),
      );
    });

    test('requireDocumentTypePermission delegates to warid', () {
      final session = ServerSession(
        userId: 2,
        username: 'user',
        role: 'user',
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: false,
        canImportExcel: false,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(
        () => requireDocumentTypePermission(session, 'warid'),
        returnsNormally,
      );
      expect(
        () => requireDocumentTypePermission(session, 'sadir'),
        throwsA(isA<ApiException>()),
      );
    });

    test('requireDocumentTypePermission throws for empty type', () {
      final session = ServerSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: false,
        canManageWarid: false,
        canManageSadir: false,
        canImportExcel: false,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(
        () => requireDocumentTypePermission(session, ''),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          HttpStatus.badRequest,
        )),
      );
    });

    test('requireDocumentTypePermission throws for unknown type', () {
      final session = ServerSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: false,
        canManageWarid: false,
        canManageSadir: false,
        canImportExcel: false,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(
        () => requireDocumentTypePermission(session, 'unknown'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // middleware.dart - RateLimiter
  // ---------------------------------------------------------------------------

  group('RateLimiter', () {
    test('allows requests under the limit', () {
      final limiter = RateLimiter(maxAttempts: 3, window: const Duration(minutes: 5));
      expect(limiter.allowRequest('1.2.3.4'), isTrue);
      expect(limiter.allowRequest('1.2.3.4'), isTrue);
      expect(limiter.allowRequest('1.2.3.4'), isTrue);
    });

    test('blocks requests over the limit', () {
      final limiter = RateLimiter(maxAttempts: 2, window: const Duration(minutes: 5));
      expect(limiter.allowRequest('1.2.3.4'), isTrue);
      expect(limiter.allowRequest('1.2.3.4'), isTrue);
      expect(limiter.allowRequest('1.2.3.4'), isFalse);
    });

    test('different IPs are tracked independently', () {
      final limiter = RateLimiter(maxAttempts: 1, window: const Duration(minutes: 5));
      expect(limiter.allowRequest('1.1.1.1'), isTrue);
      expect(limiter.allowRequest('2.2.2.2'), isTrue);
      expect(limiter.allowRequest('1.1.1.1'), isFalse);
      expect(limiter.allowRequest('2.2.2.2'), isFalse);
    });

    test('retryAfterSeconds returns positive value when rate limited', () {
      final limiter = RateLimiter(maxAttempts: 1, window: const Duration(minutes: 5));
      limiter.allowRequest('1.2.3.4');
      limiter.allowRequest('1.2.3.4'); // over limit

      final retry = limiter.retryAfterSeconds('1.2.3.4');
      expect(retry, greaterThan(0));
      expect(retry, lessThanOrEqualTo(300)); // 5 minutes
    });

    test('retryAfterSeconds returns 0 for unknown IP', () {
      final limiter = RateLimiter(maxAttempts: 5, window: const Duration(minutes: 5));
      expect(limiter.retryAfterSeconds('unknown'), 0);
    });
  });

  group('RequestLogger', () {
    test('can be constructed with enabled=true and enabled=false', () {
      const enabledLogger = RequestLogger(enabled: true);
      const disabledLogger = RequestLogger(enabled: false);
      expect(enabledLogger.enabled, isTrue);
      expect(disabledLogger.enabled, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // session_store.dart - ServerSession
  // ---------------------------------------------------------------------------

  group('ServerSession', () {
    test('isAdmin returns true for admin role', () {
      final session = ServerSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: true,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: true,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(session.isAdmin, isTrue);
      expect(session.isExpired, isFalse);
    });

    test('isAdmin is case-insensitive', () {
      final session = ServerSession(
        userId: 1,
        username: 'admin',
        role: '  Admin  ',
        canManageUsers: true,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: true,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(session.isAdmin, isTrue);
    });

    test('isAdmin returns false for non-admin role', () {
      final session = ServerSession(
        userId: 2,
        username: 'user',
        role: 'user',
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: false,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(session.isAdmin, isFalse);
    });

    test('isExpired returns true for past date', () {
      final session = ServerSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: true,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: true,
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(session.isExpired, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // session_store.dart - SessionStore (with in-memory SQLite)
  // ---------------------------------------------------------------------------

  group('SessionStore', () {
    late Database db;
    late SessionStore store;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      store = SessionStore(sessionTtl: const Duration(hours: 1));
      await store.initialize(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('createSession returns a non-empty token', () async {
      final token = await store.createSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: true,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: true,
      );
      expect(token, isNotEmpty);
    });

    test('find returns the session for a valid token', () async {
      final token = await store.createSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: true,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: false,
      );

      final session = store.find(token);
      expect(session, isNotNull);
      expect(session!.userId, 1);
      expect(session.username, 'admin');
      expect(session.role, 'admin');
      expect(session.canManageUsers, isTrue);
      expect(session.canImportExcel, isFalse);
    });

    test('find returns null for unknown token', () {
      expect(store.find('nonexistent-token'), isNull);
    });

    test('removeSession invalidates the token', () async {
      final token = await store.createSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: true,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: true,
      );

      await store.removeSession(token);
      expect(store.find(token), isNull);
    });

    test('refreshSession returns a new token and invalidates old', () async {
      final oldToken = await store.createSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: true,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: true,
      );

      final newToken = await store.refreshSession(oldToken);
      expect(newToken, isNotNull);
      expect(newToken, isNot(oldToken));

      // Old token should be invalid.
      expect(store.find(oldToken), isNull);

      // New token should work.
      final session = store.find(newToken!);
      expect(session, isNotNull);
      expect(session!.userId, 1);
      expect(session.username, 'admin');
    });

    test('refreshSession returns null for unknown token', () async {
      final result = await store.refreshSession('nonexistent');
      expect(result, isNull);
    });

    test('each createSession generates unique tokens', () async {
      final tokens = <String>{};
      for (var i = 0; i < 20; i++) {
        final token = await store.createSession(
          userId: 1,
          username: 'admin',
          role: 'admin',
          canManageUsers: true,
          canManageWarid: true,
          canManageSadir: true,
          canImportExcel: true,
        );
        tokens.add(token);
      }
      expect(tokens.length, 20); // All unique.
    });

    test('sessions are persisted in SQLite', () async {
      final token = await store.createSession(
        userId: 42,
        username: 'testuser',
        role: 'user',
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: false,
        canImportExcel: false,
      );

      // Verify the row exists in the database.
      final rows = await db.query(
        'server_sessions',
        where: 'token = ?',
        whereArgs: [token],
      );
      expect(rows, hasLength(1));
      expect(rows.first['user_id'], 42);
      expect(rows.first['username'], 'testuser');
    });

    test('expired sessions are not returned by find', () async {
      // Create a store with a very short TTL.
      final shortStore = SessionStore(
        sessionTtl: const Duration(milliseconds: 50),
      );
      await shortStore.initialize(db);

      final token = await shortStore.createSession(
        userId: 1,
        username: 'admin',
        role: 'admin',
        canManageUsers: true,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: true,
      );

      // Wait for it to expire.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(shortStore.find(token), isNull);
    });

    test('sessions survive re-initialization (persistence)', () async {
      final token = await store.createSession(
        userId: 7,
        username: 'persistent',
        role: 'user',
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: false,
      );

      // Create a new store on the same DB (simulates restart).
      final newStore = SessionStore(sessionTtl: const Duration(hours: 1));
      await newStore.initialize(db);

      final session = newStore.find(token);
      expect(session, isNotNull);
      expect(session!.userId, 7);
      expect(session.username, 'persistent');
    });
  });
}
