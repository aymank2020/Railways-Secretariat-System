import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/open.dart';

import 'package:railway_secretariat/core/services/database_service.dart';
import 'package:railway_secretariat/features/auth/data/repositories/database_auth_repository.dart';
import 'package:railway_secretariat/features/documents/data/datasources/attachment_storage_service.dart';
import 'package:railway_secretariat/features/documents/data/datasources/excel_import_service.dart';
import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/documents/data/models/warid_model.dart';
import 'package:railway_secretariat/features/documents/data/repositories/database_document_repository.dart';
import 'package:railway_secretariat/features/ocr/data/models/ocr_template_model.dart';
import 'package:railway_secretariat/features/ocr/data/repositories/database_ocr_template_repository.dart';
import 'package:railway_secretariat/features/system/data/repositories/database_system_repository.dart';
import 'package:railway_secretariat/features/users/data/models/user_model.dart';
import 'package:railway_secretariat/features/users/data/repositories/database_user_repository.dart';

import 'package:railway_secretariat/server/helpers.dart';
import 'package:railway_secretariat/server/middleware.dart';
import 'package:railway_secretariat/server/session_store.dart';

final Stopwatch _serverUptime = Stopwatch();

Future<void> main() async {
  _serverUptime.start();

  // On Linux/macOS servers (no Flutter, no bundled sqlite3 native asset),
  // override sqlite3 to load from the system library explicitly.
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, () {
      // Try versioned name first, fall back to unversioned.
      try {
        return DynamicLibrary.open('libsqlite3.so.0');
      } catch (_) {
        return DynamicLibrary.open('libsqlite3.so');
      }
    });
  } else if (Platform.isMacOS) {
    open.overrideFor(
        OperatingSystem.macOS, () => DynamicLibrary.open('libsqlite3.dylib'));
  }

  final host = Platform.environment['SECRETARIAT_SERVER_HOST'] ?? '0.0.0.0';
  final port = int.tryParse(
        Platform.environment['SECRETARIAT_SERVER_PORT'] ?? '8080',
      ) ??
      8080;

  // CORS configuration from environment.
  final corsOrigins = Platform.environment['SECRETARIAT_CORS_ORIGINS']
      ?.split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  // Logging control.
  final enableLogging =
      (Platform.environment['SECRETARIAT_LOG_REQUESTS'] ?? '1') != '0';
  final logger = RequestLogger(enabled: enableLogging);

  // Rate limiter for login endpoint.
  final loginRateLimiter = RateLimiter(
    maxAttempts: int.tryParse(
          Platform.environment['SECRETARIAT_LOGIN_RATE_LIMIT'] ?? '10',
        ) ??
        10,
    window: const Duration(minutes: 5),
  );

  // The PRAGMA journal_mode/busy_timeout setup lives in
  // [DatabaseService._onConfigure] under the `_serverMode` branch — calling
  // [enableServerMode] before [database] ensures WAL is applied on the very
  // first open instead of being toggled afterwards.
  DatabaseService.enableServerMode();
  final databaseService = DatabaseService();
  final db = await databaseService.database;
  try {
    final journalRow = await db.rawQuery('PRAGMA journal_mode');
    final mode = journalRow.isNotEmpty
        ? (journalRow.first.values.first ?? '').toString()
        : '';
    stdout.writeln('SQLite journal mode: $mode');
  } catch (e) {
    stderr.writeln('Warning: Could not query journal_mode: $e');
  }

  final authRepository =
      DatabaseAuthRepository(databaseService: databaseService);
  final userRepository =
      DatabaseUserRepository(databaseService: databaseService);
  final documentRepository = DatabaseDocumentRepository(
    databaseService: databaseService,
    excelImportService: ExcelImportService(),
  );
  final attachmentStorageService = AttachmentStorageService();
  final ocrRepository =
      DatabaseOcrTemplateRepository(databaseService: databaseService);
  final systemRepository =
      DatabaseSystemRepository(databaseService: databaseService);

  // Session store with SQLite persistence.
  final sessionStore = SessionStore();
  await sessionStore.initialize(db);

  final server = await HttpServer.bind(host, port);
  stdout.writeln('Railway Secretariat API listening on http://$host:$port');
  stdout.writeln(
    'Using DB path from SECRETARIAT_DB_PATH or storage root configuration.',
  );
  if (enableLogging) {
    stdout.writeln('Request logging: enabled');
  }

  // Graceful shutdown on SIGINT / SIGTERM.
  _setupGracefulShutdown(server, db);

  await for (final request in server) {
    unawaited(
      _handleRequest(
        request: request,
        databaseService: databaseService,
        authRepository: authRepository,
        userRepository: userRepository,
        documentRepository: documentRepository,
        attachmentStorageService: attachmentStorageService,
        ocrRepository: ocrRepository,
        systemRepository: systemRepository,
        sessionStore: sessionStore,
        corsOrigins: corsOrigins,
        logger: logger,
        loginRateLimiter: loginRateLimiter,
      ),
    );
  }
}

/// Returns `true` iff [filePath], once normalised, lives inside [rootPath].
///
/// Used by the `/api/attachments/download` endpoint to reject path
/// traversal payloads such as `/etc/passwd` or
/// `managed://../../secretariat.db` that would otherwise let an
/// authenticated client read files outside the attachments directory.
bool _isPathInsideRoot(String filePath, String rootPath) {
  final normalizedRoot = p.normalize(p.absolute(rootPath));
  final normalizedFile = p.normalize(p.absolute(filePath));

  // Equal paths (root itself) count as inside.
  if (normalizedFile == normalizedRoot) return true;

  final separator = Platform.pathSeparator;
  final rootWithSeparator = normalizedRoot.endsWith(separator)
      ? normalizedRoot
      : '$normalizedRoot$separator';
  return normalizedFile.startsWith(rootWithSeparator);
}

void _setupGracefulShutdown(HttpServer server, dynamic db) {
  var shuttingDown = false;

  Future<void> shutdown(String signal) async {
    if (shuttingDown) return;
    shuttingDown = true;
    stdout.writeln('\n$signal received. Shutting down gracefully...');

    try {
      await server.close(force: false);
      stdout.writeln('HTTP server closed.');
    } catch (e) {
      stderr.writeln('Error closing HTTP server: $e');
    }

    try {
      if (db != null) {
        await db.close();
        stdout.writeln('Database closed.');
      }
    } catch (e) {
      stderr.writeln('Error closing database: $e');
    }

    stdout.writeln('Shutdown complete.');
    exit(0);
  }

  // SIGINT (Ctrl+C).
  ProcessSignal.sigint.watch().listen((_) => shutdown('SIGINT'));
  // SIGTERM (kill, systemd stop, etc.) — not available on Windows.
  try {
    ProcessSignal.sigterm.watch().listen((_) => shutdown('SIGTERM'));
  } catch (_) {
    // SIGTERM not supported on this platform (e.g., Windows).
  }
}

Future<void> _handleRequest({
  required HttpRequest request,
  required DatabaseService databaseService,
  required DatabaseAuthRepository authRepository,
  required DatabaseUserRepository userRepository,
  required DatabaseDocumentRepository documentRepository,
  required AttachmentStorageService attachmentStorageService,
  required DatabaseOcrTemplateRepository ocrRepository,
  required DatabaseSystemRepository systemRepository,
  required SessionStore sessionStore,
  required List<String>? corsOrigins,
  required RequestLogger logger,
  required RateLimiter loginRateLimiter,
}) async {
  final response = request.response;
  final timer = Stopwatch()..start();
  setCorsHeaders(response, allowedOrigins: corsOrigins);

  logger.logRequest(request);

  if (request.method == 'OPTIONS') {
    response.statusCode = HttpStatus.noContent;
    await response.close();
    logger.logResponse(request, HttpStatus.noContent, timer);
    return;
  }

  try {
    final path = request.uri.path;

    // -----------------------------------------------------------------------
    // Health check (unauthenticated)
    // -----------------------------------------------------------------------
    if (request.method == 'GET' && path == '/api/health') {
      writeJson(response, <String, dynamic>{
        'status': 'ok',
        'time': DateTime.now().toIso8601String(),
        'version': '1.0.5+6',
        'uptime': _serverUptime.elapsed.inSeconds,
      });
      return;
    }

    // -----------------------------------------------------------------------
    // Authentication
    // -----------------------------------------------------------------------
    if (request.method == 'POST' && path == '/api/auth/login') {
      final clientIp = getClientIp(request);
      if (!loginRateLimiter.allowRequest(clientIp)) {
        final retryAfter = loginRateLimiter.retryAfterSeconds(clientIp);
        response.headers.set('Retry-After', '$retryAfter');
        throw ApiException(
          HttpStatus.tooManyRequests,
          'Too many login attempts. Try again in $retryAfter seconds.',
        );
      }

      final body = await readJsonBody(request);
      final username = (body['username'] ?? '').toString().trim();
      final password = (body['password'] ?? '').toString();

      if (username.isEmpty || password.isEmpty) {
        throw const ApiException(
          HttpStatus.badRequest,
          'Username and password are required.',
        );
      }

      final user = await authRepository.authenticate(
        username: username,
        password: password,
      );
      if (user == null) {
        throw const ApiException(
          HttpStatus.unauthorized,
          'Invalid username or password.',
        );
      }

      final token = await sessionStore.createSession(
        userId: user.id ?? 0,
        username: user.username,
        role: user.role,
        canManageUsers: user.canManageUsers,
        canManageWarid: user.canManageWarid,
        canManageSadir: user.canManageSadir,
        canImportExcel: user.canImportExcel,
      );

      writeJson(response, <String, dynamic>{
        'token': token,
        'user': user.toMap(includePassword: false),
      });
      return;
    }

    // -----------------------------------------------------------------------
    // Token refresh (authenticated)
    // -----------------------------------------------------------------------
    if (request.method == 'POST' && path == '/api/auth/refresh') {
      final oldToken = extractToken(request);
      if (oldToken.isEmpty) {
        throw const ApiException(
          HttpStatus.unauthorized,
          'Missing bearer token.',
        );
      }

      final newToken = await sessionStore.refreshSession(oldToken);
      if (newToken == null) {
        throw const ApiException(
          HttpStatus.unauthorized,
          'Invalid or expired token.',
        );
      }

      writeJson(response, <String, dynamic>{'token': newToken});
      return;
    }

    // All subsequent routes require authentication.
    final session = requireSession(request, sessionStore);

    // -----------------------------------------------------------------------
    // Logout
    // -----------------------------------------------------------------------
    if (request.method == 'POST' && path == '/api/auth/logout') {
      final token = extractToken(request);
      await sessionStore.removeSession(token);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    // -----------------------------------------------------------------------
    // Attachments
    // -----------------------------------------------------------------------
    if (request.method == 'POST' && path == '/api/attachments/upload') {
      final body = await readJsonBody(request);
      final fileName = (body['fileName'] ?? '').toString().trim();
      final documentType = (body['documentType'] ?? '').toString().trim();
      final fileBytes =
          decodeBase64((body['fileBytesBase64'] ?? '').toString());
      final isFollowup = parseBool(body['isFollowup']);

      if (fileName.isEmpty || documentType.isEmpty || fileBytes.isEmpty) {
        throw const ApiException(
          HttpStatus.badRequest,
          'Invalid attachment upload payload.',
        );
      }

      requireDocumentTypePermission(session, documentType);

      final storedPath = await attachmentStorageService.storeAttachmentBytes(
        fileBytes: fileBytes,
        originalFileName: fileName,
        documentType: documentType,
        isFollowup: isFollowup,
      );
      if (storedPath == null || storedPath.trim().isEmpty) {
        throw const ApiException(
          HttpStatus.internalServerError,
          'Failed to store attachment.',
        );
      }

      writeJson(response, <String, dynamic>{
        'fileName': fileName,
        'filePath': storedPath,
      });
      return;
    }

    if (request.method == 'POST' && path == '/api/attachments/download') {
      requireDocumentAccessPermission(session);
      final body = await readJsonBody(request);
      final filePath = (body['filePath'] ?? '').toString().trim();
      if (filePath.isEmpty) {
        throw const ApiException(
          HttpStatus.badRequest,
          'filePath is required.',
        );
      }

      final resolvedPath =
          await attachmentStorageService.resolveAttachmentPath(filePath);
      if (resolvedPath == null || resolvedPath.trim().isEmpty) {
        throw const ApiException(HttpStatus.notFound, 'Attachment not found.');
      }

      // Defense-in-depth: refuse any resolved path that escapes the
      // attachments directory. Without this, an authenticated client
      // could send `{"filePath": "/etc/passwd"}` or
      // `{"filePath": "managed://../../secretariat.db"}` and read
      // arbitrary files inside the container.
      final attachmentsRoot =
          await attachmentStorageService.getAttachmentsRootForServer();
      if (!_isPathInsideRoot(resolvedPath, attachmentsRoot)) {
        throw const ApiException(
          HttpStatus.forbidden,
          'Refused: filePath is outside the attachments directory.',
        );
      }

      final file = File(resolvedPath);
      if (!await file.exists()) {
        throw const ApiException(
          HttpStatus.notFound,
          'Attachment file is missing.',
        );
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const ApiException(
          HttpStatus.notFound,
          'Attachment file is empty.',
        );
      }

      writeJson(response, <String, dynamic>{
        'fileName': p.basename(resolvedPath),
        'fileBytesBase64': base64Encode(bytes),
      });
      return;
    }

    // -----------------------------------------------------------------------
    // Password management
    // -----------------------------------------------------------------------
    if (request.method == 'POST' && path == '/api/auth/change-password') {
      final body = await readJsonBody(request);
      final userId = parseInt(body['userId']?.toString());
      final newPassword = (body['newPassword'] ?? '').toString();
      if (userId == null || newPassword.trim().isEmpty) {
        throw const ApiException(
          HttpStatus.badRequest,
          'Invalid change password payload.',
        );
      }
      if (!session.isAdmin && session.userId != userId) {
        throw const ApiException(
          HttpStatus.forbidden,
          'You do not have permission to change this password.',
        );
      }

      await authRepository.updatePassword(
        userId: userId,
        newPassword: newPassword,
      );
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    // -----------------------------------------------------------------------
    // Users CRUD
    // -----------------------------------------------------------------------
    if (request.method == 'GET' && path == '/api/users') {
      requireUsersPermission(session);
      final users = await userRepository.getAllUsers();
      writeJson(
        response,
        users.map((item) => item.toMap(includePassword: false)).toList(),
      );
      return;
    }

    if (request.method == 'POST' && path == '/api/users') {
      requireUsersPermission(session);
      final body = await readJsonBody(request);
      final userMap = ensureMap(body['user'], fieldName: 'user');
      final user = UserModel.fromMap(userMap);
      await userRepository.insertUser(user);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    if (request.method == 'PUT' && path.startsWith('/api/users/')) {
      requireUsersPermission(session);
      final id = int.tryParse(path.substring('/api/users/'.length));
      if (id == null) {
        throw const ApiException(HttpStatus.badRequest, 'Invalid user id.');
      }
      final body = await readJsonBody(request);
      final userMap = ensureMap(body['user'], fieldName: 'user');
      userMap['id'] = id;
      final user = UserModel.fromMap(userMap);
      final newPassword = body['newPassword']?.toString();
      await userRepository.updateUser(user, newPassword: newPassword);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    if (request.method == 'DELETE' && path.startsWith('/api/users/')) {
      requireUsersPermission(session);
      final id = int.tryParse(path.substring('/api/users/'.length));
      if (id == null) {
        throw const ApiException(HttpStatus.badRequest, 'Invalid user id.');
      }
      await userRepository.deleteUser(id);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    // -----------------------------------------------------------------------
    // Warid CRUD
    // -----------------------------------------------------------------------
    if (request.method == 'GET' && path == '/api/documents/warid') {
      requireWaridPermission(session);
      final query = request.uri.queryParameters;
      final items = await documentRepository.getAllWarid(
        search: query['search'],
        fromDate: parseDate(query['fromDate']),
        toDate: parseDate(query['toDate']),
        externalNumber: query['externalNumber'],
        externalDate: parseDate(query['externalDate']),
        chairmanIncomingNumber: query['chairmanIncomingNumber'],
        chairmanIncomingDate: parseDate(query['chairmanIncomingDate']),
        chairmanReturnNumber: query['chairmanReturnNumber'],
        chairmanReturnDate: parseDate(query['chairmanReturnDate']),
        limit: parseInt(query['limit']),
        offset: parseInt(query['offset']),
      );
      writeJson(response, items.map((item) => item.toMap()).toList());
      return;
    }

    if (request.method == 'GET' &&
        path.startsWith('/api/documents/warid/') &&
        !path.endsWith('/delete')) {
      requireWaridPermission(session);
      final id = int.tryParse(path.substring('/api/documents/warid/'.length));
      if (id == null) {
        throw const ApiException(HttpStatus.badRequest, 'Invalid warid id.');
      }
      final item = await databaseService.getWaridById(id);
      if (item == null) {
        throw const ApiException(
            HttpStatus.notFound, 'Warid record not found.');
      }
      writeJson(response, item.toMap());
      return;
    }

    if (request.method == 'POST' && path == '/api/documents/warid') {
      requireWaridPermission(session);
      final body = await readJsonBody(request);
      final waridMap = ensureMap(body['warid'], fieldName: 'warid');
      final warid = WaridModel.fromMap(waridMap);
      await documentRepository.insertWarid(warid);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    if (request.method == 'PUT' && path.startsWith('/api/documents/warid/')) {
      requireWaridPermission(session);
      final id = int.tryParse(path.substring('/api/documents/warid/'.length));
      if (id == null) {
        throw const ApiException(HttpStatus.badRequest, 'Invalid warid id.');
      }
      final body = await readJsonBody(request);
      final map = ensureMap(body['warid'], fieldName: 'warid');
      map['id'] = id;
      final userId = parseInt(body['userId']?.toString()) ?? session.userId;
      final userName = (body['userName'] ?? session.username).toString().trim();
      final warid = WaridModel.fromMap(map);
      await documentRepository.updateWarid(warid, userId, userName);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    if (request.method == 'POST' &&
        path.startsWith('/api/documents/warid/') &&
        path.endsWith('/delete')) {
      requireWaridPermission(session);
      final idText = path
          .replaceFirst('/api/documents/warid/', '')
          .replaceFirst('/delete', '');
      final id = int.tryParse(idText);
      if (id == null) {
        throw const ApiException(HttpStatus.badRequest, 'Invalid warid id.');
      }
      final body = await readJsonBody(request);
      final userId = parseInt(body['userId']?.toString()) ?? session.userId;
      final userName = (body['userName'] ?? session.username).toString().trim();
      await documentRepository.deleteWarid(id, userId, userName);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    // -----------------------------------------------------------------------
    // Warid batch delete
    // -----------------------------------------------------------------------
    if (request.method == 'POST' &&
        path == '/api/documents/warid/batch-delete') {
      requireWaridPermission(session);
      final body = await readJsonBody(request);
      final rawIds = body['ids'];
      if (rawIds is! List || rawIds.isEmpty) {
        throw const ApiException(
          HttpStatus.badRequest,
          'ids must be a non-empty array.',
        );
      }
      final ids = rawIds
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toSet()
          .toList();
      final userId = parseInt(body['userId']?.toString()) ?? session.userId;
      final userName = (body['userName'] ?? session.username).toString().trim();

      var deletedCount = 0;
      var failedCount = 0;
      for (final id in ids) {
        try {
          await documentRepository.deleteWarid(id, userId, userName);
          deletedCount++;
        } catch (_) {
          failedCount++;
        }
      }
      writeJson(response, <String, dynamic>{
        'deletedCount': deletedCount,
        'failedCount': failedCount,
      });
      return;
    }

    // -----------------------------------------------------------------------
    // Sadir CRUD
    // -----------------------------------------------------------------------
    if (request.method == 'GET' && path == '/api/documents/sadir') {
      requireSadirPermission(session);
      final query = request.uri.queryParameters;
      final items = await documentRepository.getAllSadir(
        search: query['search'],
        fromDate: parseDate(query['fromDate']),
        toDate: parseDate(query['toDate']),
        externalNumber: query['externalNumber'],
        externalDate: parseDate(query['externalDate']),
        chairmanIncomingNumber: query['chairmanIncomingNumber'],
        chairmanIncomingDate: parseDate(query['chairmanIncomingDate']),
        chairmanReturnNumber: query['chairmanReturnNumber'],
        chairmanReturnDate: parseDate(query['chairmanReturnDate']),
        limit: parseInt(query['limit']),
        offset: parseInt(query['offset']),
      );
      writeJson(response, items.map((item) => item.toMap()).toList());
      return;
    }

    if (request.method == 'GET' &&
        path.startsWith('/api/documents/sadir/') &&
        !path.endsWith('/delete')) {
      requireSadirPermission(session);
      final id = int.tryParse(path.substring('/api/documents/sadir/'.length));
      if (id == null) {
        throw const ApiException(HttpStatus.badRequest, 'Invalid sadir id.');
      }
      final item = await databaseService.getSadirById(id);
      if (item == null) {
        throw const ApiException(
            HttpStatus.notFound, 'Sadir record not found.');
      }
      writeJson(response, item.toMap());
      return;
    }

    if (request.method == 'POST' && path == '/api/documents/sadir') {
      requireSadirPermission(session);
      final body = await readJsonBody(request);
      final sadirMap = ensureMap(body['sadir'], fieldName: 'sadir');
      final sadir = SadirModel.fromMap(sadirMap);
      await documentRepository.insertSadir(sadir);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    if (request.method == 'PUT' && path.startsWith('/api/documents/sadir/')) {
      requireSadirPermission(session);
      final id = int.tryParse(path.substring('/api/documents/sadir/'.length));
      if (id == null) {
        throw const ApiException(HttpStatus.badRequest, 'Invalid sadir id.');
      }
      final body = await readJsonBody(request);
      final map = ensureMap(body['sadir'], fieldName: 'sadir');
      map['id'] = id;
      final userId = parseInt(body['userId']?.toString()) ?? session.userId;
      final userName = (body['userName'] ?? session.username).toString().trim();
      final sadir = SadirModel.fromMap(map);
      await documentRepository.updateSadir(sadir, userId, userName);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    if (request.method == 'POST' &&
        path.startsWith('/api/documents/sadir/') &&
        path.endsWith('/delete')) {
      requireSadirPermission(session);
      final idText = path
          .replaceFirst('/api/documents/sadir/', '')
          .replaceFirst('/delete', '');
      final id = int.tryParse(idText);
      if (id == null) {
        throw const ApiException(HttpStatus.badRequest, 'Invalid sadir id.');
      }
      final body = await readJsonBody(request);
      final userId = parseInt(body['userId']?.toString()) ?? session.userId;
      final userName = (body['userName'] ?? session.username).toString().trim();
      await documentRepository.deleteSadir(id, userId, userName);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    // -----------------------------------------------------------------------
    // Sadir batch delete
    // -----------------------------------------------------------------------
    if (request.method == 'POST' &&
        path == '/api/documents/sadir/batch-delete') {
      requireSadirPermission(session);
      final body = await readJsonBody(request);
      final rawIds = body['ids'];
      if (rawIds is! List || rawIds.isEmpty) {
        throw const ApiException(
          HttpStatus.badRequest,
          'ids must be a non-empty array.',
        );
      }
      final ids = rawIds
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .toSet()
          .toList();
      final userId = parseInt(body['userId']?.toString()) ?? session.userId;
      final userName = (body['userName'] ?? session.username).toString().trim();

      var deletedCount = 0;
      var failedCount = 0;
      for (final id in ids) {
        try {
          await documentRepository.deleteSadir(id, userId, userName);
          deletedCount++;
        } catch (_) {
          failedCount++;
        }
      }
      writeJson(response, <String, dynamic>{
        'deletedCount': deletedCount,
        'failedCount': failedCount,
      });
      return;
    }

    // -----------------------------------------------------------------------
    // Deleted records
    // -----------------------------------------------------------------------
    if (request.method == 'GET' && path == '/api/documents/deleted') {
      if (!session.canManageWarid &&
          !session.canManageSadir &&
          !session.isAdmin) {
        throw const ApiException(
          HttpStatus.forbidden,
          'You do not have permission to view deleted records.',
        );
      }
      final query = request.uri.queryParameters;
      final items = await documentRepository.getDeletedRecords(
        documentType: query['documentType'],
        includeRestored: (query['includeRestored'] ?? '0') == '1',
        search: query['search'],
        limit: parseInt(query['limit']),
        offset: parseInt(query['offset']),
      );
      writeJson(response, items.map(deletedRecordToMap).toList());
      return;
    }

    if (request.method == 'POST' && path == '/api/documents/deleted/restore') {
      if (!session.canManageWarid &&
          !session.canManageSadir &&
          !session.isAdmin) {
        throw const ApiException(
          HttpStatus.forbidden,
          'You do not have permission to restore deleted records.',
        );
      }
      final body = await readJsonBody(request);
      final deletedRecordId = parseInt(body['deletedRecordId']?.toString());
      final qaidNumber = (body['qaidNumber'] ?? '').toString().trim();
      final userId = parseInt(body['userId']?.toString()) ?? session.userId;
      final userName = (body['userName'] ?? session.username).toString().trim();

      if (deletedRecordId == null || qaidNumber.isEmpty) {
        throw const ApiException(
          HttpStatus.badRequest,
          'Invalid restore payload.',
        );
      }

      await documentRepository.restoreDeletedRecord(
        deletedRecordId: deletedRecordId,
        qaidNumber: qaidNumber,
        userId: userId,
        userName: userName,
      );
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    if (request.method == 'POST' &&
        path == '/api/documents/deleted/restore-with-payload') {
      final body = await readJsonBody(request);
      final deletedRecordId = parseInt(body['deletedRecordId']?.toString());
      final documentType = (body['documentType'] ?? '').toString().trim();
      requireDocumentTypePermission(session, documentType);
      final payload = ensureMap(body['payload'], fieldName: 'payload');
      final qaidNumber = (body['qaidNumber'] ?? '').toString().trim();
      final userId = parseInt(body['userId']?.toString()) ?? session.userId;
      final userName = (body['userName'] ?? session.username).toString().trim();

      if (deletedRecordId == null ||
          documentType.isEmpty ||
          qaidNumber.isEmpty) {
        throw const ApiException(
          HttpStatus.badRequest,
          'Invalid restore-with-payload payload.',
        );
      }

      await documentRepository.restoreDeletedRecordWithPayload(
        deletedRecordId: deletedRecordId,
        documentType: documentType,
        payload: payload,
        qaidNumber: qaidNumber,
        userId: userId,
        userName: userName,
      );
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    // -----------------------------------------------------------------------
    // Statistics
    // -----------------------------------------------------------------------
    if (request.method == 'GET' && path == '/api/documents/statistics') {
      if (!session.canManageWarid &&
          !session.canManageSadir &&
          !session.isAdmin) {
        throw const ApiException(
          HttpStatus.forbidden,
          'You do not have permission to view statistics.',
        );
      }
      final stats = await documentRepository.getStatistics();
      writeJson(response, stats);
      return;
    }

    // -----------------------------------------------------------------------
    // Classification options
    // -----------------------------------------------------------------------
    if (request.method == 'GET' &&
        path.startsWith('/api/documents/classification/')) {
      final documentType =
          path.substring('/api/documents/classification/'.length).trim();
      requireDocumentTypePermission(session, documentType);
      final options =
          await documentRepository.getClassificationOptions(documentType);
      writeJson(response, options);
      return;
    }

    if (request.method == 'POST' && path == '/api/documents/classification') {
      final body = await readJsonBody(request);
      final documentType = (body['documentType'] ?? '').toString().trim();
      final optionName = (body['optionName'] ?? '').toString().trim();
      requireDocumentTypePermission(session, documentType);
      if (documentType.isEmpty || optionName.isEmpty) {
        throw const ApiException(
          HttpStatus.badRequest,
          'Invalid classification payload.',
        );
      }
      await documentRepository.addClassificationOption(
        documentType: documentType,
        optionName: optionName,
      );
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    // -----------------------------------------------------------------------
    // Excel import
    // -----------------------------------------------------------------------
    if (request.method == 'POST' && path == '/api/documents/import/warid') {
      requireImportPermission(session);
      requireWaridPermission(session);
      final body = await readJsonBody(request);
      final outcome = await documentRepository.importWaridFromExcel(
        fileBytes: decodeBase64((body['fileBytesBase64'] ?? '').toString()),
        fileName: (body['fileName'] ?? '').toString(),
        filePath: body['filePath']?.toString(),
        userId: parseInt(body['userId']?.toString()),
        userName: body['userName']?.toString(),
      );
      writeJson(response, importOutcomeToMap(outcome));
      return;
    }

    if (request.method == 'POST' && path == '/api/documents/import/sadir') {
      requireImportPermission(session);
      requireSadirPermission(session);
      final body = await readJsonBody(request);
      final outcome = await documentRepository.importSadirFromExcel(
        fileBytes: decodeBase64((body['fileBytesBase64'] ?? '').toString()),
        fileName: (body['fileName'] ?? '').toString(),
        filePath: body['filePath']?.toString(),
        userId: parseInt(body['userId']?.toString()),
        userName: body['userName']?.toString(),
      );
      writeJson(response, importOutcomeToMap(outcome));
      return;
    }

    // -----------------------------------------------------------------------
    // OCR templates
    // -----------------------------------------------------------------------
    if (request.method == 'GET' && path == '/api/ocr/templates') {
      final documentType = request.uri.queryParameters['documentType'];
      if (documentType != null && documentType.trim().isNotEmpty) {
        requireDocumentTypePermission(session, documentType);
      }
      final templates = await ocrRepository.getTemplates(
        documentType: documentType,
      );
      writeJson(response, templates.map((item) => item.toMap()).toList());
      return;
    }

    if (request.method == 'POST' && path == '/api/ocr/templates') {
      requireImportPermission(session);
      final body = await readJsonBody(request);
      final templateMap = ensureMap(body['template'], fieldName: 'template');
      final template = OcrTemplateModel.fromMap(templateMap);
      final id = await ocrRepository.saveTemplate(template);
      writeJson(response, <String, dynamic>{'id': id});
      return;
    }

    if (request.method == 'DELETE' && path.startsWith('/api/ocr/templates/')) {
      requireImportPermission(session);
      final id = int.tryParse(path.substring('/api/ocr/templates/'.length));
      if (id == null) {
        throw const ApiException(HttpStatus.badRequest, 'Invalid template id.');
      }
      await ocrRepository.deleteTemplate(id);
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    // -----------------------------------------------------------------------
    // Audit log
    // -----------------------------------------------------------------------
    if (request.method == 'GET' && path == '/api/audit-log') {
      if (!session.isAdmin) {
        throw const ApiException(
          HttpStatus.forbidden,
          'Only admin users can view audit logs.',
        );
      }
      final query = request.uri.queryParameters;
      final entries = await databaseService.getAuditLog(
        recordId: parseInt(query['recordId']),
        tableName: query['tableName'],
      );
      writeJson(response, entries);
      return;
    }

    // -----------------------------------------------------------------------
    // System
    // -----------------------------------------------------------------------
    if (request.method == 'POST' && path == '/api/system/reset-db') {
      if (!session.isAdmin) {
        throw const ApiException(
          HttpStatus.forbidden,
          'Only admin users can reset database connections.',
        );
      }
      await systemRepository.resetDatabaseConnection();
      writeJson(response, <String, dynamic>{'ok': true});
      return;
    }

    throw const ApiException(HttpStatus.notFound, 'Route not found.');
  } on ApiException catch (e) {
    response.statusCode = e.statusCode;
    writeJson(response, <String, dynamic>{'message': e.message});
  } on ConcurrentUpdateException catch (e) {
    response.statusCode = HttpStatus.conflict;
    writeJson(response, <String, dynamic>{'message': e.message});
  } on StateError catch (e) {
    response.statusCode = HttpStatus.badRequest;
    writeJson(response, <String, dynamic>{'message': e.toString()});
  } catch (e, st) {
    stderr.writeln('Server error: $e');
    stderr.writeln(st);
    response.statusCode = HttpStatus.internalServerError;
    writeJson(response, <String, dynamic>{
      'message': 'Internal server error. Check server logs for details.',
    });
  } finally {
    timer.stop();
    logger.logResponse(request, response.statusCode, timer);
    await response.close();
  }
}
