import 'dart:io';

import 'package:test/test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:railway_secretariat/server/helpers.dart';
import 'package:railway_secretariat/server/middleware.dart';
import 'package:railway_secretariat/server/rate_limit_store.dart';
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

  // ---------------------------------------------------------------------------
  // helpers - getClientIp (rate-limit bypass prevention)
  //
  // nginx is configured with `proxy_set_header X-Real-IP $remote_addr;` and
  // `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`. The
  // latter APPENDS the real client IP to whatever the client sent, so the
  // first entry is attacker-controllable. The login rate-limiter MUST key
  // off a trustworthy value; otherwise an attacker can rotate the spoofed
  // IP on every attempt and fully bypass the lockout.
  // ---------------------------------------------------------------------------

  group('helpers - getClientIp', () {
    Future<String> roundTrip({Map<String, String> headers = const {}}) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final completer = <String>[];
      server.listen((req) {
        completer.add(getClientIp(req));
        req.response.statusCode = HttpStatus.ok;
        req.response.close();
      });

      try {
        final client = HttpClient();
        final hreq = await client
            .getUrl(Uri.parse('http://127.0.0.1:${server.port}/'));
        headers.forEach(hreq.headers.set);
        final resp = await hreq.close();
        await resp.drain<void>();
        client.close(force: true);
      } finally {
        await server.close(force: true);
      }
      return completer.first;
    }

    test('falls back to the TCP peer when no proxy headers are present',
        () async {
      final ip = await roundTrip();
      // Loopback can come back as 127.0.0.1 or ::1 depending on dual-stack.
      expect(ip, anyOf('127.0.0.1', '::1'));
    });

    test('prefers X-Real-IP over X-Forwarded-For', () async {
      final ip = await roundTrip(headers: {
        'X-Real-IP': '10.0.0.42',
        'X-Forwarded-For': '1.2.3.4, 10.0.0.42',
      });
      expect(ip, '10.0.0.42');
    });

    test(
        'reads the LAST X-Forwarded-For entry so a spoofed prefix cannot bypass '
        'the rate-limiter', () async {
      // Simulates: attacker sends `X-Forwarded-For: 9.9.9.9`; nginx appends
      // the real peer (10.0.0.7) to produce `9.9.9.9, 10.0.0.7`. We must
      // key off `10.0.0.7`, not `9.9.9.9`.
      final ip = await roundTrip(headers: {
        'X-Forwarded-For': '9.9.9.9, 10.0.0.7',
      });
      expect(ip, '10.0.0.7');
    });

    test('handles X-Forwarded-For with extra whitespace', () async {
      final ip = await roundTrip(headers: {
        'X-Forwarded-For': '  9.9.9.9 ,   10.0.0.7   ',
      });
      expect(ip, '10.0.0.7');
    });

    test('a single-entry X-Forwarded-For is used as-is', () async {
      final ip = await roundTrip(headers: {
        'X-Forwarded-For': '10.0.0.55',
      });
      expect(ip, '10.0.0.55');
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

  // ---------------------------------------------------------------------------
  // RateLimitStore (§4.6 — persistence across restart)
  //
  // Each test uses a fresh in-memory database so the store starts empty;
  // the assertions cover the wire-up that turns a process-local map into
  // a restart-resistant counter.
  // ---------------------------------------------------------------------------

  group('RateLimitStore', () {
    late Database db;
    late RateLimitStore store;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
      store = await RateLimitStore.open(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('open creates the rate_limit_attempts table and indexes', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name='rate_limit_attempts'",
      );
      expect(tables.length, 1);

      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type='index' AND tbl_name='rate_limit_attempts' "
        "ORDER BY name",
      );
      final indexNames = indexes.map((r) => r['name'] as String).toList();
      expect(indexNames, contains('idx_rate_limit_attempts_ip_time'));
      expect(indexNames, contains('idx_rate_limit_attempts_time'));
    });

    test('recordAttempt + loadAttemptsSince round-trips per-IP timestamps',
        () async {
      final t0 = DateTime.utc(2026, 5, 4, 18);
      await store.recordAttempt('1.1.1.1', t0);
      await store.recordAttempt('1.1.1.1', t0.add(const Duration(seconds: 1)));
      await store.recordAttempt('2.2.2.2', t0.add(const Duration(seconds: 2)));

      final loaded =
          await store.loadAttemptsSince(t0.subtract(const Duration(hours: 1)));
      expect(loaded.keys.toSet(), {'1.1.1.1', '2.2.2.2'});
      expect(loaded['1.1.1.1']!.length, 2);
      expect(loaded['2.2.2.2']!.length, 1);
      // Each list is returned in chronological order.
      expect(loaded['1.1.1.1']!.first.isBefore(loaded['1.1.1.1']!.last), isTrue);
    });

    test('loadAttemptsSince filters out attempts older than the cutoff',
        () async {
      final now = DateTime.utc(2026, 5, 4, 18);
      await store.recordAttempt('1.1.1.1', now.subtract(const Duration(hours: 2)));
      await store.recordAttempt('1.1.1.1', now.subtract(const Duration(minutes: 1)));

      final loaded =
          await store.loadAttemptsSince(now.subtract(const Duration(minutes: 10)));
      expect(loaded.keys, contains('1.1.1.1'));
      expect(loaded['1.1.1.1']!.length, 1,
          reason: 'only the recent attempt should survive the cutoff');
    });

    test('purgeBefore deletes only rows older than the cutoff', () async {
      final now = DateTime.utc(2026, 5, 4, 18);
      await store.recordAttempt(
          'old', now.subtract(const Duration(hours: 24)));
      await store.recordAttempt(
          'new', now.subtract(const Duration(seconds: 5)));

      final removed =
          await store.purgeBefore(now.subtract(const Duration(hours: 1)));
      expect(removed, 1);

      final remaining = await db.query('rate_limit_attempts');
      expect(remaining.length, 1);
      expect(remaining.first['ip'], 'new');
    });
  });

  group('RateLimiter persistence (§4.6)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('attachStore re-hydrates the in-memory tracker from SQLite',
        () async {
      // Phase 1 — first "process": attach a store, exhaust the bucket.
      final firstStore = await RateLimitStore.open(db);
      final firstLimiter = RateLimiter(
        maxAttempts: 2,
        window: const Duration(minutes: 5),
      );
      await firstLimiter.attachStore(firstStore);

      expect(firstLimiter.allowRequest('1.2.3.4'), isTrue);
      expect(firstLimiter.allowRequest('1.2.3.4'), isTrue);
      expect(firstLimiter.allowRequest('1.2.3.4'), isFalse,
          reason: '3rd attempt is over the limit');

      // Wait long enough for the fire-and-forget store.recordAttempt
      // futures to flush before we tear down.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Phase 2 — simulate a restart by building a brand-new limiter
      // against the SAME database. The pre-existing rows must
      // re-populate the counter so the offending IP is still blocked.
      final secondStore = await RateLimitStore.open(db);
      final secondLimiter = RateLimiter(
        maxAttempts: 2,
        window: const Duration(minutes: 5),
      );
      await secondLimiter.attachStore(secondStore);

      expect(secondLimiter.allowRequest('1.2.3.4'), isFalse,
          reason: 'restart must not reset the counter');
    });

    test('attachStore is idempotent on the same RateLimiter instance',
        () async {
      final store = await RateLimitStore.open(db);
      final limiter = RateLimiter(
        maxAttempts: 1,
        window: const Duration(minutes: 5),
      );
      await limiter.attachStore(store);
      // Second call must not throw, must not corrupt internal state.
      await limiter.attachStore(store);
      expect(limiter.allowRequest('5.5.5.5'), isTrue);
      expect(limiter.allowRequest('5.5.5.5'), isFalse);
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

    test(
        'removeAllSessionsForUser revokes every session except exceptToken',
        () async {
      // Three sessions for user 5 (different devices) + one for user 6.
      final tokenA = await store.createSession(
        userId: 5,
        username: 'alice',
        role: 'user',
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: false,
      );
      final tokenB = await store.createSession(
        userId: 5,
        username: 'alice',
        role: 'user',
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: false,
      );
      final tokenC = await store.createSession(
        userId: 5,
        username: 'alice',
        role: 'user',
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: false,
      );
      final tokenOther = await store.createSession(
        userId: 6,
        username: 'bob',
        role: 'user',
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: false,
      );

      // Rotate alice's password while logged in on tokenB; the others must
      // be revoked but tokenB and bob's session must survive.
      final removedCount =
          await store.removeAllSessionsForUser(5, exceptToken: tokenB);
      expect(removedCount, 2);

      expect(store.find(tokenA), isNull);
      expect(store.find(tokenB), isNotNull);
      expect(store.find(tokenC), isNull);
      expect(store.find(tokenOther), isNotNull);

      // The DB row for the kept session must still be there too.
      final rows = await db.query(
        'server_sessions',
        where: 'user_id = ?',
        whereArgs: [5],
      );
      expect(rows, hasLength(1));
      expect(rows.first['token'], tokenB);
    });

    test(
        'removeAllSessionsForUser without exceptToken revokes every session',
        () async {
      await store.createSession(
        userId: 9,
        username: 'eve',
        role: 'user',
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: false,
      );
      await store.createSession(
        userId: 9,
        username: 'eve',
        role: 'user',
        canManageUsers: false,
        canManageWarid: true,
        canManageSadir: true,
        canImportExcel: false,
      );

      final removedCount = await store.removeAllSessionsForUser(9);
      expect(removedCount, 2);

      final rows = await db.query(
        'server_sessions',
        where: 'user_id = ?',
        whereArgs: [9],
      );
      expect(rows, isEmpty);
    });
  });
}
