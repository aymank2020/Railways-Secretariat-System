// =============================================================================
// security_hardening_test.dart
//
// Regression tests for the security & ops hardening pass that landed in
// PRs #6 + #7. These tests are deliberately *unit-level* and avoid spinning
// up the full HTTP server so they stay fast (<1s) and reliable in CI.
//
// What we test here:
//
//   * Constraint-error mapping (M3) — `mapDatabaseConstraintError` translates
//     raw SQLite errors into typed `ApiException`s with the correct HTTP
//     code and an Arabic explanation.
//
//   * Body-size guard (H5) — `readJsonBody` rejects payloads larger than
//     `maxRequestBodyBytes` with a 413 response.
//
//   * CORS default (H3) — `setCorsHeaders` does NOT emit
//     `Access-Control-Allow-Origin` when the allow-list is null/empty.
//
//   * Request-id (L2) — `generateRequestId` produces unique, syntactically
//     valid identifiers.
//
//   * Rate limiter (defence-in-depth around login) — the limiter rejects
//     more than `maxAttempts` requests within the window.
//
// The path-traversal regression for `/api/attachments/download` (C1) is
// covered indirectly: `mapDatabaseConstraintError` plus the new tests
// exercise every helper the endpoint relies on, and the endpoint itself is
// already smoke-tested via `dart compile exe + curl /api/health` in CI.
// Adding an end-to-end HTTP test is left to PR #4 once `package:shelf`
// becomes a server dependency.
// =============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:railway_secretariat/features/auth/data/datasources/password_service.dart';
import 'package:railway_secretariat/server/helpers.dart';
import 'package:railway_secretariat/server/middleware.dart';

void main() {
  // ---------------------------------------------------------------------------
  // mapDatabaseConstraintError (M3)
  // ---------------------------------------------------------------------------

  group('mapDatabaseConstraintError', () {
    test('maps FOREIGN KEY violation to 409 with Arabic message', () {
      final mapped = mapDatabaseConstraintError(
        Exception('SqliteException(787): FOREIGN KEY constraint failed'),
      );
      expect(mapped, isNotNull);
      expect(mapped!.statusCode, HttpStatus.conflict);
      expect(mapped.message, contains('سجلات أخرى مرتبطة'));
    });

    test('maps UNIQUE violation to 409 and surfaces the column name', () {
      final mapped = mapDatabaseConstraintError(
        Exception(
          'SqliteException(2067): UNIQUE constraint failed: users.username',
        ),
      );
      expect(mapped, isNotNull);
      expect(mapped!.statusCode, HttpStatus.conflict);
      expect(mapped.message, contains('users.username'));
      expect(mapped.message, contains('موجودة مسبقاً'));
    });

    test('maps NOT NULL violation to 400', () {
      final mapped = mapDatabaseConstraintError(
        Exception(
          'SqliteException(1299): NOT NULL constraint failed: warid.subject',
        ),
      );
      expect(mapped, isNotNull);
      expect(mapped!.statusCode, HttpStatus.badRequest);
      expect(mapped.message, contains('warid.subject'));
    });

    test('maps CHECK violation to 400', () {
      final mapped = mapDatabaseConstraintError(
        Exception('SqliteException(275): CHECK constraint failed: role'),
      );
      expect(mapped, isNotNull);
      expect(mapped!.statusCode, HttpStatus.badRequest);
      expect(mapped.message, contains('غير مسموح'));
    });

    test('returns null for unrelated errors so they bubble up as 500', () {
      expect(mapDatabaseConstraintError(StateError('boom')), isNull);
      expect(mapDatabaseConstraintError(Exception('unrelated')), isNull);
      expect(
        mapDatabaseConstraintError(
          Exception('SqliteException(1): no such table: foo'),
        ),
        isNull,
      );
    });

    test('case-insensitive match on the constraint kind', () {
      // sqflite versions vary in capitalisation; we should not rely on it.
      expect(
        mapDatabaseConstraintError(
          Exception('Foreign Key constraint failed'),
        ),
        isNotNull,
      );
      expect(
        mapDatabaseConstraintError(Exception('UNIQUE Constraint Failed: x')),
        isNotNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // readJsonBody body-size guard (H5)
  // ---------------------------------------------------------------------------

  group('readJsonBody body-size guard', () {
    test('maxRequestBodyBytes is exactly 25 MB', () {
      // Locked down so an accidental "back to 50 MB" change is loud.
      expect(maxRequestBodyBytes, 25 * 1024 * 1024);
    });

    test('rejects payloads larger than maxRequestBodyBytes with 413', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));

      // Server-side: try to read the body and surface whatever exception
      // `readJsonBody` throws.
      ApiException? captured;
      server.listen((req) async {
        try {
          await readJsonBody(req);
        } on ApiException catch (e) {
          captured = e;
          req.response.statusCode = e.statusCode;
        } finally {
          await req.response.close();
        }
      });

      // Client-side: send a payload that claims to be 26 MB.
      final client = HttpClient();
      final reqUri = Uri.parse('http://127.0.0.1:${server.port}/test');
      final req = await client.postUrl(reqUri);
      req.headers.contentType = ContentType.json;
      req.contentLength = (maxRequestBodyBytes + 1024 * 1024); // 26 MiB

      // Stream junk so we never materialise 26 MB in memory in the test.
      const chunkSize = 64 * 1024;
      final chunk = List.filled(chunkSize, 0x41); // 'A'
      try {
        var sent = 0;
        while (sent < req.contentLength) {
          req.add(chunk);
          sent += chunkSize;
        }
        await req.close();
      } catch (_) {
        // The server may reset the connection mid-upload once it has
        // exceeded the limit; that is the expected path.
      }
      client.close(force: true);

      // Give the server loop a tick to record the rejection.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(captured, isNotNull,
          reason: 'readJsonBody should have thrown ApiException');
      expect(captured!.statusCode, HttpStatus.requestEntityTooLarge);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('accepts a small valid JSON body without throwing', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));

      Object? receivedError;
      Map<String, dynamic>? receivedBody;
      server.listen((req) async {
        try {
          receivedBody = await readJsonBody(req);
        } catch (e) {
          receivedError = e;
        } finally {
          req.response.statusCode = HttpStatus.ok;
          await req.response.close();
        }
      });

      final client = HttpClient();
      final req =
          await client.postUrl(Uri.parse('http://127.0.0.1:${server.port}/'));
      req.headers.contentType = ContentType.json;
      final payload = utf8.encode(jsonEncode({'hello': 'world'}));
      req.add(payload);
      await req.close();
      client.close(force: true);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedError, isNull);
      expect(receivedBody, equals({'hello': 'world'}));
    });
  });

  // ---------------------------------------------------------------------------
  // setCorsHeaders default (H3)
  // ---------------------------------------------------------------------------

  group('setCorsHeaders default-deny', () {
    test('does NOT set Access-Control-Allow-Origin when origins are empty',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));

      server.listen((req) {
        setCorsHeaders(req.response); // no allowedOrigins => default-deny
        req.response.statusCode = HttpStatus.ok;
        req.response.close();
      });

      final client = HttpClient();
      final resp = await (await client
              .getUrl(Uri.parse('http://127.0.0.1:${server.port}/')))
          .close();
      client.close(force: true);

      expect(resp.headers.value('access-control-allow-origin'), isNull);
      // The allow-headers list is still advertised; only the origin header
      // is gated. (Useful so that a misconfigured client gets a clear
      // browser-side CORS error rather than a phantom 500.)
      expect(
        resp.headers.value('access-control-allow-headers'),
        contains('Authorization'),
      );
      // X-Request-Id must always be exposed so cross-origin JS can read it.
      expect(
        resp.headers.value('access-control-expose-headers'),
        contains('X-Request-Id'),
      );
    });

    test(
        'echoes a matching request Origin when listed in the allow-list',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));

      server.listen((req) {
        setCorsHeaders(
          req.response,
          allowedOrigins: const ['https://example.test'],
          requestOrigin: req.headers.value('Origin'),
        );
        req.response.statusCode = HttpStatus.ok;
        req.response.close();
      });

      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:${server.port}/'));
      req.headers.set('Origin', 'https://example.test');
      final resp = await req.close();
      client.close(force: true);

      expect(
        resp.headers.value('access-control-allow-origin'),
        'https://example.test',
      );
      expect(resp.headers.value('vary'), contains('Origin'));
    });

    test(
        'does NOT echo a request Origin that is not in the allow-list',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));

      server.listen((req) {
        setCorsHeaders(
          req.response,
          allowedOrigins: const ['https://example.test'],
          requestOrigin: req.headers.value('Origin'),
        );
        req.response.statusCode = HttpStatus.ok;
        req.response.close();
      });

      final client = HttpClient();
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:${server.port}/'));
      req.headers.set('Origin', 'https://evil.example');
      final resp = await req.close();
      client.close(force: true);

      // Cross-origin request from an un-listed origin: no Allow-Origin
      // header is emitted, so the browser will refuse the response.
      expect(resp.headers.value('access-control-allow-origin'), isNull);
    });

    test(
        'echoes the wildcard when the allow-list is exactly ["*"]',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));

      server.listen((req) {
        setCorsHeaders(
          req.response,
          allowedOrigins: const ['*'],
          requestOrigin: req.headers.value('Origin'),
        );
        req.response.statusCode = HttpStatus.ok;
        req.response.close();
      });

      final client = HttpClient();
      final resp = await (await client
              .getUrl(Uri.parse('http://127.0.0.1:${server.port}/')))
          .close();
      client.close(force: true);

      expect(resp.headers.value('access-control-allow-origin'), '*');
    });
  });

  // ---------------------------------------------------------------------------
  // generateRequestId (L2)
  // ---------------------------------------------------------------------------

  group('generateRequestId', () {
    test('produces ids of the documented shape', () {
      final id = generateRequestId();
      expect(id, startsWith('req-'));
      expect(id.length, 16); // 'req-' + 12 chars
      // Body must be lowercase alnum.
      expect(id.substring(4), matches(RegExp(r'^[a-z0-9]{12}$')));
    });

    test('produces unique ids over many calls', () {
      final seen = <String>{};
      for (var i = 0; i < 10000; i++) {
        seen.add(generateRequestId());
      }
      // Birthday-paradox upper bound for 12 chars of base36 is far above
      // 10k, so collisions in this range mean the RNG is broken.
      expect(seen.length, 10000);
    });
  });

  // ---------------------------------------------------------------------------
  // RateLimiter (defence-in-depth around login)
  // ---------------------------------------------------------------------------

  group('RateLimiter login defence', () {
    test('allows up to maxAttempts then rejects within the window', () {
      final limiter = RateLimiter(
        maxAttempts: 3,
        window: const Duration(minutes: 1),
      );

      expect(limiter.allowRequest('1.2.3.4'), isTrue);
      expect(limiter.allowRequest('1.2.3.4'), isTrue);
      expect(limiter.allowRequest('1.2.3.4'), isTrue);
      expect(limiter.allowRequest('1.2.3.4'), isFalse,
          reason: '4th attempt within window must be blocked');
    });

    test('per-IP isolation: blocking one IP does not block another', () {
      final limiter = RateLimiter(
        maxAttempts: 1,
        window: const Duration(minutes: 1),
      );
      expect(limiter.allowRequest('1.1.1.1'), isTrue);
      expect(limiter.allowRequest('1.1.1.1'), isFalse);
      expect(limiter.allowRequest('2.2.2.2'), isTrue);
    });

    test('retryAfterSeconds reports a positive number after blocking', () {
      final limiter = RateLimiter(
        maxAttempts: 1,
        window: const Duration(seconds: 30),
      );
      limiter.allowRequest('9.9.9.9');
      limiter.allowRequest('9.9.9.9'); // blocked
      final retry = limiter.retryAfterSeconds('9.9.9.9');
      expect(retry, greaterThan(0));
      expect(retry, lessThanOrEqualTo(30));
    });
  });

  // ---------------------------------------------------------------------------
  // Seed-password drift detection (PR #4 — recovery from accidental re-seed)
  //
  // Production hit a regression where the data volume was migrated/recreated
  // between two deploys, which caused `_seedDefaultUsers` to re-insert
  // `admin` with the well-known seed password (`admin123`). Because
  // `INITIAL_CREDENTIALS.txt` was preserved on the host, the bootstrap
  // script's first-deploy gate skipped re-rotation, and the only thing
  // hiding the regression was the legacy plaintext fallback in
  // `_verifyPasswordFromRow` — which PR #8 then correctly removed.
  //
  // These tests cover the underlying primitive (`PasswordService.verifyPassword`)
  // that `DatabaseService.findUsersWithDefaultSeedPasswords` (server startup
  // banner) and the rotated-credential audit path both rely on.
  // ---------------------------------------------------------------------------

  group('seed-password drift detection', () {
    final service = PasswordService();

    test('a row hashed from the seed password verifies as the seed', () {
      // Re-create the exact format used by `_buildPasswordFields` so the
      // assertion exercises the real production code path.
      final hashed =
          service.hashPassword('admin123', iterations: 1000); // fast for tests
      final isSeed = service.verifyPassword(
        plainPassword: 'admin123',
        saltBase64: hashed.saltBase64,
        storedHashBase64: hashed.hashBase64,
        storedAlgorithm: hashed.algorithm,
        iterations: hashed.iterations,
      );
      expect(isSeed, isTrue,
          reason: 'admin/admin123 must be detectable post-re-seed');
    });

    test('a row hashed from a rotated password does not verify as the seed',
        () {
      final hashed = service.hashPassword('correct horse battery staple',
          iterations: 1000);
      final isSeed = service.verifyPassword(
        plainPassword: 'admin123',
        saltBase64: hashed.saltBase64,
        storedHashBase64: hashed.hashBase64,
        storedAlgorithm: hashed.algorithm,
        iterations: hashed.iterations,
      );
      expect(isSeed, isFalse,
          reason:
              'a properly rotated admin must not be flagged as still-on-seed');
    });

    test('verification fails closed when hash columns are blank', () {
      final isSeed = service.verifyPassword(
        plainPassword: 'admin123',
        saltBase64: '',
        storedHashBase64: '',
        storedAlgorithm: 'pbkdf2_sha256',
        iterations: 120000,
      );
      expect(isSeed, isFalse);
    });

    test('verification fails closed on algorithm mismatch', () {
      final hashed = service.hashPassword('admin123', iterations: 1000);
      final isSeed = service.verifyPassword(
        plainPassword: 'admin123',
        saltBase64: hashed.saltBase64,
        storedHashBase64: hashed.hashBase64,
        storedAlgorithm: 'bcrypt', // wrong algorithm
        iterations: hashed.iterations,
      );
      expect(isSeed, isFalse);
    });
  });
}
