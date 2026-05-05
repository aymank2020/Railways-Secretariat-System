import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

import 'package:railway_secretariat/core/platform/foundation_shims.dart'
    if (dart.library.ui) 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, kIsWeb;
import 'package:path/path.dart';
import 'package:railway_secretariat/core/platform/path_provider_shims.dart'
    if (dart.library.ui) 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:railway_secretariat/core/platform/sqflite_web_shims.dart'
    if (dart.library.html) 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:railway_secretariat/features/history/data/models/deleted_record_model.dart';
import 'package:railway_secretariat/features/ocr/data/models/ocr_field_definitions.dart';
import 'package:railway_secretariat/features/ocr/data/models/ocr_template_model.dart';

import 'package:railway_secretariat/features/documents/data/models/sadir_model.dart';
import 'package:railway_secretariat/features/users/data/models/user_model.dart';
import 'package:railway_secretariat/features/documents/data/models/warid_model.dart';
import 'package:railway_secretariat/features/auth/data/datasources/password_service.dart';
import 'package:railway_secretariat/core/services/storage_location_service.dart';

class ConcurrentUpdateException implements Exception {
  final String message;

  const ConcurrentUpdateException(this.message);

  @override
  String toString() => message;
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static bool _webRecoveryAttempted = false;
  static bool _serverMode = false;
  static const int _dbVersion = 9;

  /// Marks this process as the embedded Dart API server. Must be called
  /// before any access to [DatabaseService.database] so that [_onConfigure]
  /// can pick the right journal mode (WAL for the server vs. DELETE for
  /// the desktop / mobile Flutter app).
  static void enableServerMode() {
    _serverMode = true;
  }

  static const Duration _webDbQueryTimeout = Duration(seconds: 15);
  static const String _envDatabasePathKey = 'SECRETARIAT_DB_PATH';
  static const int _busyRetryAttempts = 7;
  static const Duration _busyRetryDelay = Duration(milliseconds: 220);
  static const String _classificationMinistry =
      '\u0627\u0644\u0648\u0632\u0627\u0631\u0629';
  static const String _classificationAuthority =
      '\u0627\u0644\u0647\u064A\u0626\u0629';
  static const String _classificationTransportPolice =
      '\u0634\u0631\u0637\u0629 \u0627\u0644\u0646\u0642\u0644 \u0648\u0627\u0644\u0645\u0648\u0627\u0635\u0644\u0627\u062A';
  static const String _classificationCentralOrganization =
      '\u0627\u0644\u062C\u0647\u0627\u0632 \u0627\u0644\u0645\u0631\u0643\u0632\u064A \u0644\u0644\u062A\u0646\u0638\u064A\u0645 \u0648\u0627\u0644\u0625\u062F\u0627\u0631\u0629';

  final PasswordService _passwordService = PasswordService();
  final StorageLocationService _storageLocationService =
      StorageLocationService();

  /// Tracks tables where every `qaid_number` is already in canonical
  /// form (digits-only, no surrounding whitespace, no Arabic/Eastern
  /// Arabic-Indic digits). Once a table is marked clean here, the
  /// validator can rely on the unique index alone and skip the legacy
  /// secondary scan that previously fetched every row into memory and
  /// re-normalised it in Dart (the O(N)-per-insert path called out in
  /// the §6.1 finding). The set is process-local because the migration
  /// state lives in SQLite — restarts re-verify lazily.
  final Set<String> _qaidNumberCleanTables = <String>{};

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[DatabaseService] $message');
    }
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<T> _withWebTimeout<T>(Future<T> future,
      [Duration timeout = _webDbQueryTimeout]) {
    if (!kIsWeb) {
      return future;
    }
    return future.timeout(timeout);
  }

  Future<T> _withBusyRetry<T>(Future<T> Function() action) async {
    var attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (e) {
        final message = e.toString().toLowerCase();
        final isBusy = message.contains('database is locked') ||
            message.contains('sqlitedbusy') ||
            message.contains('sqlite_busy') ||
            message.contains('busy');
        if (!isBusy || attempt >= _busyRetryAttempts - 1) {
          rethrow;
        }

        attempt++;
        await Future<void>.delayed(
          Duration(
            milliseconds: _busyRetryDelay.inMilliseconds * attempt,
          ),
        );
      }
    }
  }

  void _assertNoConcurrentRecordUpdate({
    required DateTime? currentUpdatedAt,
    required DateTime? incomingUpdatedAt,
    required String documentType,
    required int recordId,
  }) {
    final currentMillis = currentUpdatedAt?.millisecondsSinceEpoch;
    final incomingMillis = incomingUpdatedAt?.millisecondsSinceEpoch;

    final hasConflict = currentMillis != incomingMillis;
    if (!hasConflict) {
      return;
    }

    throw ConcurrentUpdateException(
      'تم تعديل سجل $documentType رقم $recordId بواسطة مستخدم آخر. '
      'يرجى تحديث الشاشة وإعادة المحاولة.',
    );
  }

  Future<String> _resolveDatabasePath() async {
    if (kIsWeb) {
      return 'secretariat.db';
    }

    final envDbPath = Platform.environment[_envDatabasePathKey]?.trim();
    if (envDbPath != null && envDbPath.isNotEmpty) {
      final targetFromEnv = normalize(absolute(envDbPath));
      await File(targetFromEnv).parent.create(recursive: true);
      await _migrateLegacyDatabaseIfNeeded(targetFromEnv);
      return targetFromEnv;
    }

    final targetPath = await _storageLocationService.getDatabasePath();
    await _migrateLegacyDatabaseIfNeeded(targetPath);
    return targetPath;
  }

  Future<void> _migrateLegacyDatabaseIfNeeded(String targetPath) async {
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      return;
    }

    final legacyCandidates = <String>{};
    try {
      final legacyAppSupport = await getApplicationSupportDirectory();
      legacyCandidates.add(join(legacyAppSupport.path, 'secretariat.db'));
    } catch (_) {}
    try {
      final legacyDocuments = await getApplicationDocumentsDirectory();
      legacyCandidates.add(join(legacyDocuments.path, 'secretariat.db'));
    } catch (_) {}

    for (final legacyPath in legacyCandidates) {
      if (_isSamePath(legacyPath, targetPath)) {
        continue;
      }

      try {
        final legacyFile = File(legacyPath);
        if (!await legacyFile.exists()) {
          continue;
        }

        await targetFile.parent.create(recursive: true);
        await legacyFile.copy(targetPath);
        _debugLog('legacy database migrated from $legacyPath');
        return;
      } catch (e) {
        _debugLog('legacy database migration skipped from $legacyPath: $e');
      }
    }
  }

  Future<Database> _initDatabase() async {
    _debugLog('initDatabase start (web=$kIsWeb)');
    if (kIsWeb) {
      // Use the non-worker factory for better compatibility/stability on Flutter Web.
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await _resolveDatabasePath();

    var db = await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _debugLog('openDatabase done');

    try {
      _debugLog('ensurePostOpenData start');
      await _ensurePostOpenData(db);
      _debugLog('ensurePostOpenData done');
    } catch (e) {
      // Web databases can become inconsistent after interrupted schema upgrades.
      // Recreate once to recover instead of failing login forever.
      if (!kIsWeb) rethrow;
      _debugLog('ensurePostOpenData failed, recreating db: $e');
      await db.close();
      await deleteDatabase(path);
      db = await openDatabase(
        path,
        version: _dbVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      await _ensurePostOpenData(db);
    }
    _webRecoveryAttempted = false;
    _debugLog('initDatabase done');
    return db;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');

    if (kIsWeb) {
      return;
    }

    await db.execute('PRAGMA synchronous = NORMAL');

    if (_serverMode) {
      // The embedded Dart server may serve concurrent reads/writes from many
      // browser sessions, so WAL is the right tradeoff (writers do not block
      // readers). A 10s busy-timeout keeps the API responsive under load.
      await db.execute('PRAGMA busy_timeout = 10000');
      await db.execute('PRAGMA journal_mode = WAL');
    } else {
      // Single-writer desktop / mobile / unit-test scenarios: rollback
      // journal is simpler, plays nicer with backups (no -wal/-shm files
      // to forget) and avoids surprising behaviour after force-quit.
      await db.execute('PRAGMA busy_timeout = 5000');
      await db.execute('PRAGMA journal_mode = DELETE');
    }
  }

  bool _isSamePath(String first, String second) {
    var normalizedFirst = normalize(absolute(first));
    var normalizedSecond = normalize(absolute(second));
    if (!kIsWeb && Platform.isWindows) {
      normalizedFirst = normalizedFirst.toLowerCase();
      normalizedSecond = normalizedSecond.toLowerCase();
    }
    return normalizedFirst == normalizedSecond;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        password_salt TEXT,
        password_hash TEXT,
        password_algo TEXT,
        password_iterations INTEGER DEFAULT 0,
        full_name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT,
        role TEXT NOT NULL DEFAULT 'user',
        is_active INTEGER NOT NULL DEFAULT 1,
        can_manage_users INTEGER NOT NULL DEFAULT 0,
        can_manage_warid INTEGER NOT NULL DEFAULT 1,
        can_manage_sadir INTEGER NOT NULL DEFAULT 1,
        can_import_excel INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_login TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE warid (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        qaid_number TEXT NOT NULL,
        qaid_date TEXT NOT NULL,
        source_administration TEXT NOT NULL,
        letter_number TEXT,
        letter_date TEXT,
        chairman_incoming_number TEXT,
        chairman_incoming_date TEXT,
        chairman_return_number TEXT,
        chairman_return_date TEXT,
        attachment_count INTEGER DEFAULT 0,
        subject TEXT NOT NULL,
        notes TEXT,
        recipient_1_name TEXT,
        recipient_1_delivery_date TEXT,
        recipient_2_name TEXT,
        recipient_2_delivery_date TEXT,
        recipient_3_name TEXT,
        recipient_3_delivery_date TEXT,
        is_ministry INTEGER DEFAULT 0,
        is_authority INTEGER DEFAULT 0,
        is_other INTEGER DEFAULT 0,
        other_details TEXT,
        file_name TEXT,
        file_path TEXT,
        needs_followup INTEGER DEFAULT 0,
        followup_notes TEXT,
        followup_status TEXT DEFAULT 'waiting_reply',
        followup_file_name TEXT,
        followup_file_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        created_by INTEGER,
        created_by_name TEXT,
        import_file_id INTEGER,
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sadir (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        qaid_number TEXT NOT NULL,
        qaid_date TEXT NOT NULL,
        destination_administration TEXT,
        letter_number TEXT,
        letter_date TEXT,
        chairman_incoming_number TEXT,
        chairman_incoming_date TEXT,
        chairman_return_number TEXT,
        chairman_return_date TEXT,
        attachment_count INTEGER DEFAULT 0,
        subject TEXT NOT NULL,
        notes TEXT,
        signature_status TEXT DEFAULT 'pending',
        signature_date TEXT,
        sent_to_1_name TEXT,
        sent_to_1_delivery_date TEXT,
        sent_to_2_name TEXT,
        sent_to_2_delivery_date TEXT,
        sent_to_3_name TEXT,
        sent_to_3_delivery_date TEXT,
        is_ministry INTEGER DEFAULT 0,
        is_authority INTEGER DEFAULT 0,
        is_other INTEGER DEFAULT 0,
        other_details TEXT,
        file_name TEXT,
        file_path TEXT,
        needs_followup INTEGER DEFAULT 0,
        followup_notes TEXT,
        followup_status TEXT DEFAULT 'waiting_reply',
        followup_file_name TEXT,
        followup_file_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        created_by INTEGER,
        created_by_name TEXT,
        import_file_id INTEGER,
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE import_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_type TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT,
        file_bytes BLOB,
        total_rows INTEGER NOT NULL DEFAULT 0,
        imported_rows INTEGER NOT NULL DEFAULT 0,
        failed_rows INTEGER NOT NULL DEFAULT 0,
        imported_by INTEGER,
        imported_by_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        old_values TEXT,
        new_values TEXT,
        user_id INTEGER,
        user_name TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await _ensureDeletedRecordsTable(db);
    await _ensureClassificationOptions(db);
    await _ensureOcrTemplates(db);
    await _ensureUniqueQaidIndexes(db);
    await _seedDefaultUsers(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS import_files (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          document_type TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_path TEXT,
          file_bytes BLOB,
          total_rows INTEGER NOT NULL DEFAULT 0,
          imported_rows INTEGER NOT NULL DEFAULT 0,
          failed_rows INTEGER NOT NULL DEFAULT 0,
          imported_by INTEGER,
          imported_by_name TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT
        )
      ''');

      await _addColumnIfNotExists(db, 'warid', 'import_file_id INTEGER');
      await _addColumnIfNotExists(db, 'sadir', 'import_file_id INTEGER');
    }

    if (oldVersion < 3) {
      await _addColumnIfNotExists(db, 'users', 'password_salt TEXT');
      await _addColumnIfNotExists(db, 'users', 'password_hash TEXT');
      await _addColumnIfNotExists(db, 'users', 'password_algo TEXT');
      await _addColumnIfNotExists(
          db, 'users', 'password_iterations INTEGER DEFAULT 0');
      await _addColumnIfNotExists(
          db, 'users', 'can_manage_users INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfNotExists(
          db, 'users', 'can_manage_warid INTEGER NOT NULL DEFAULT 1');
      await _addColumnIfNotExists(
          db, 'users', 'can_manage_sadir INTEGER NOT NULL DEFAULT 1');
      await _addColumnIfNotExists(
          db, 'users', 'can_import_excel INTEGER NOT NULL DEFAULT 0');
    }

    if (oldVersion < 4) {
      await _ensureUniqueQaidIndexes(db);
    }

    if (oldVersion < 5) {
      await _ensureClassificationOptions(db);
    }

    if (oldVersion < 6) {
      await _ensureDeletedRecordsTable(db);
    }

    if (oldVersion < 7) {
      await _ensureFollowupColumns(db);
    }

    if (oldVersion < 8) {
      await _ensureRoutingNumberColumns(db);
    }

    if (oldVersion < 9) {
      await _ensureOcrTemplates(db);
    }
  }

  Future<void> _ensurePostOpenData(Database db) async {
    await _ensurePermissionDefaults(db);
    await _migrateLegacyPasswords(db);
    await _seedDefaultUsers(db);
    await _normalizeBootstrapUsersForWeb(db);
    await _ensureUniqueQaidIndexes(db);
    await _ensurePerformanceIndexes(db);
    await _ensureDeletedRecordsTable(db);
    await _ensureClassificationOptions(db);
    await _ensureOcrTemplates(db);
    await _ensureFollowupColumns(db);
    await _ensureRoutingNumberColumns(db);
  }

  Future<void> _ensureFollowupColumns(Database db) async {
    await _addColumnIfNotExists(
        db, 'warid', "followup_status TEXT DEFAULT 'waiting_reply'");
    await _addColumnIfNotExists(db, 'warid', 'followup_file_name TEXT');
    await _addColumnIfNotExists(db, 'warid', 'followup_file_path TEXT');
    await _addColumnIfNotExists(
        db, 'sadir', "followup_status TEXT DEFAULT 'waiting_reply'");
    await _addColumnIfNotExists(db, 'sadir', 'followup_file_name TEXT');
    await _addColumnIfNotExists(db, 'sadir', 'followup_file_path TEXT');

    await db.execute('''
      UPDATE warid
      SET followup_status = CASE
        WHEN COALESCE(needs_followup, 0) = 1 THEN 'waiting_reply'
        ELSE 'completed'
      END
      WHERE followup_status IS NULL OR TRIM(followup_status) = ''
    ''');

    await db.execute('''
      UPDATE sadir
      SET followup_status = CASE
        WHEN COALESCE(needs_followup, 0) = 1 THEN 'waiting_reply'
        ELSE 'completed'
      END
      WHERE followup_status IS NULL OR TRIM(followup_status) = ''
    ''');
  }

  Future<void> _ensureRoutingNumberColumns(Database db) async {
    await _addColumnIfNotExists(db, 'warid', 'chairman_incoming_number TEXT');
    await _addColumnIfNotExists(db, 'warid', 'chairman_incoming_date TEXT');
    await _addColumnIfNotExists(db, 'warid', 'chairman_return_number TEXT');
    await _addColumnIfNotExists(db, 'warid', 'chairman_return_date TEXT');

    await _addColumnIfNotExists(db, 'sadir', 'chairman_incoming_number TEXT');
    await _addColumnIfNotExists(db, 'sadir', 'chairman_incoming_date TEXT');
    await _addColumnIfNotExists(db, 'sadir', 'chairman_return_number TEXT');
    await _addColumnIfNotExists(db, 'sadir', 'chairman_return_date TEXT');
  }

  Future<void> _addColumnIfNotExists(
      Database db, String table, String columnDefinition) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDefinition');
    } catch (_) {
      // Ignore if column already exists.
    }
  }

  Future<void> _ensureClassificationOptions(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS classification_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_type TEXT NOT NULL,
        option_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_classification_options_unique
      ON classification_options (document_type, option_name)
    ''');

    await _seedClassificationOptions(db, 'warid');
    await _seedClassificationOptions(db, 'sadir');
  }

  Future<void> _seedClassificationOptions(
      Database db, String documentType) async {
    await _insertClassificationOptionIfNotExists(
      db,
      documentType: documentType,
      optionName: _classificationMinistry,
    );
    await _insertClassificationOptionIfNotExists(
      db,
      documentType: documentType,
      optionName: _classificationAuthority,
    );
    await _insertClassificationOptionIfNotExists(
      db,
      documentType: documentType,
      optionName: _classificationTransportPolice,
    );
    await _insertClassificationOptionIfNotExists(
      db,
      documentType: documentType,
      optionName: _classificationCentralOrganization,
    );
  }

  Future<void> _insertClassificationOptionIfNotExists(
    Database db, {
    required String documentType,
    required String optionName,
  }) async {
    final normalizedDocumentType = _normalizeDocumentType(documentType);
    final normalizedOption = optionName.trim();
    if (normalizedOption.isEmpty) {
      return;
    }

    final existing = await db.query(
      'classification_options',
      columns: ['id'],
      where: 'document_type = ? AND LOWER(option_name) = LOWER(?)',
      whereArgs: [normalizedDocumentType, normalizedOption],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return;
    }

    await db.insert('classification_options', {
      'document_type': normalizedDocumentType,
      'option_name': normalizedOption,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  String _normalizeDocumentType(String documentType) {
    final normalized = documentType.trim().toLowerCase();
    if (normalized == 'warid' || normalized == 'sadir') {
      return normalized;
    }
    throw StateError('document_type must be warid or sadir.');
  }

  Future<List<String>> getClassificationOptions(String documentType) async {
    final db = await database;
    final normalizedDocumentType = _normalizeDocumentType(documentType);
    final maps = await db.query(
      'classification_options',
      columns: ['option_name'],
      where: 'document_type = ?',
      whereArgs: [normalizedDocumentType],
      orderBy: 'option_name COLLATE NOCASE ASC',
    );

    return maps
        .map((row) => (row['option_name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  Future<void> addClassificationOption({
    required String documentType,
    required String optionName,
  }) async {
    final db = await database;
    await _insertClassificationOptionIfNotExists(
      db,
      documentType: documentType,
      optionName: optionName,
    );
  }

  Future<void> _ensureOcrTemplates(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ocr_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        document_type TEXT NOT NULL,
        tesseract_language TEXT NOT NULL DEFAULT 'ara+eng',
        field_aliases TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_ocr_templates_document_type
      ON ocr_templates (document_type, created_at DESC)
    ''');

    await _insertOcrTemplateIfNotExists(
      db,
      name: 'القالب الافتراضي',
      documentType: 'warid',
      tesseractLanguage: 'ara+eng',
      fieldAliases: defaultOcrFieldAliases('warid'),
    );
    await _insertOcrTemplateIfNotExists(
      db,
      name: 'القالب الافتراضي',
      documentType: 'sadir',
      tesseractLanguage: 'ara+eng',
      fieldAliases: defaultOcrFieldAliases('sadir'),
    );
  }

  Future<void> _insertOcrTemplateIfNotExists(
    Database db, {
    required String name,
    required String documentType,
    required String tesseractLanguage,
    required Map<String, List<String>> fieldAliases,
  }) async {
    final normalizedType = _normalizeDocumentType(documentType);
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return;
    }

    final existing = await db.query(
      'ocr_templates',
      columns: ['id'],
      where: 'document_type = ? AND LOWER(name) = LOWER(?)',
      whereArgs: [normalizedType, normalizedName],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return;
    }

    await db.insert('ocr_templates', {
      'name': normalizedName,
      'document_type': normalizedType,
      'tesseract_language': tesseractLanguage.trim().isEmpty
          ? 'ara+eng'
          : tesseractLanguage.trim(),
      'field_aliases': jsonEncode(fieldAliases),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<OcrTemplateModel>> getOcrTemplates({String? documentType}) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <Object>[];

    final normalizedType = documentType?.trim();
    if (normalizedType != null && normalizedType.isNotEmpty) {
      whereParts.add('document_type = ?');
      whereArgs.add(_normalizeDocumentType(normalizedType));
    }

    final rows = await db.query(
      'ocr_templates',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
    );
    return rows.map(OcrTemplateModel.fromMap).toList();
  }

  Future<int> saveOcrTemplate(OcrTemplateModel template) async {
    final db = await database;
    final normalizedName = template.name.trim();
    if (normalizedName.isEmpty) {
      throw StateError('اسم القالب مطلوب.');
    }

    final normalizedType = _normalizeDocumentType(template.documentType);
    final conflict = await db.query(
      'ocr_templates',
      columns: ['id'],
      where: template.id == null
          ? 'document_type = ? AND LOWER(name) = LOWER(?)'
          : 'document_type = ? AND LOWER(name) = LOWER(?) AND id != ?',
      whereArgs: template.id == null
          ? <Object>[normalizedType, normalizedName]
          : <Object>[normalizedType, normalizedName, template.id!],
      limit: 1,
    );
    if (conflict.isNotEmpty) {
      throw StateError('يوجد قالب بنفس الاسم لنفس نوع السجل.');
    }

    final nowIso = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'name': normalizedName,
      'document_type': normalizedType,
      'tesseract_language': template.tesseractLanguage.trim().isEmpty
          ? 'ara+eng'
          : template.tesseractLanguage.trim(),
      'field_aliases': jsonEncode(template.fieldAliases),
      'updated_at': nowIso,
    };

    if (template.id == null) {
      payload['created_at'] = nowIso;
      return db.insert('ocr_templates', payload);
    }

    await db.update(
      'ocr_templates',
      payload,
      where: 'id = ?',
      whereArgs: [template.id],
    );
    return template.id!;
  }

  Future<void> deleteOcrTemplate(int id) async {
    final db = await database;
    await db.delete(
      'ocr_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> _ensureDeletedRecordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deleted_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        document_type TEXT NOT NULL,
        original_record_id INTEGER,
        archived_payload TEXT NOT NULL,
        deleted_at TEXT NOT NULL,
        deleted_by INTEGER,
        deleted_by_name TEXT,
        is_restored INTEGER NOT NULL DEFAULT 0,
        restored_at TEXT,
        restored_by INTEGER,
        restored_by_name TEXT,
        restored_record_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_deleted_records_lookup
      ON deleted_records (document_type, is_restored, deleted_at DESC)
    ''');
  }

  Future<void> _seedDefaultUsers(Database db) async {
    final defaultUsers = UserModel.getDefaultUsers();
    for (final user in defaultUsers) {
      final existing = await db.query(
        'users',
        where: 'username = ? COLLATE NOCASE',
        whereArgs: [user.username],
        limit: 1,
      );
      if (existing.isEmpty) {
        await _insertUserInternal(db, user);
      }
    }
  }

  Future<void> _ensurePermissionDefaults(Database db) async {
    late final List<Map<String, Object?>> users;
    try {
      users = await db.query('users', columns: [
        'id',
        'role',
        'can_manage_users',
        'can_manage_warid',
        'can_manage_sadir',
        'can_import_excel'
      ]);
    } catch (_) {
      await _addColumnIfNotExists(
          db, 'users', 'can_manage_users INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfNotExists(
          db, 'users', 'can_manage_warid INTEGER NOT NULL DEFAULT 1');
      await _addColumnIfNotExists(
          db, 'users', 'can_manage_sadir INTEGER NOT NULL DEFAULT 1');
      await _addColumnIfNotExists(
          db, 'users', 'can_import_excel INTEGER NOT NULL DEFAULT 0');
      users = await db.query('users', columns: [
        'id',
        'role',
        'can_manage_users',
        'can_manage_warid',
        'can_manage_sadir',
        'can_import_excel'
      ]);
    }

    for (final row in users) {
      final role = (row['role'] ?? 'user').toString();
      final id = row['id'] as int;

      final canManageUsers = row['can_manage_users'];
      final canManageWarid = row['can_manage_warid'];
      final canManageSadir = row['can_manage_sadir'];
      final canImportExcel = row['can_import_excel'];

      if (canManageUsers != null &&
          canManageWarid != null &&
          canManageSadir != null &&
          canImportExcel != null) {
        continue;
      }

      await db.update(
        'users',
        {
          'can_manage_users': role == 'admin' ? 1 : 0,
          'can_manage_warid': role == 'viewer' ? 0 : 1,
          'can_manage_sadir': role == 'viewer' ? 0 : 1,
          'can_import_excel': role == 'admin' ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _migrateLegacyPasswords(Database db) async {
    final rows = await db.query(
      'users',
      columns: [
        'id',
        'password',
        'password_salt',
        'password_hash',
        'password_algo',
        'password_iterations'
      ],
      where:
          "password_hash IS NULL OR password_salt IS NULL OR password_algo IS NULL OR password_algo = ''",
    );

    for (final row in rows) {
      final id = row['id'] as int;
      final plain = (row['password'] ?? '').toString();
      if (plain.isEmpty) {
        continue;
      }
      final pwdFields = _buildPasswordFields(plain);
      await db.update('users', pwdFields, where: 'id = ?', whereArgs: [id]);
    }
  }

  Map<String, dynamic> _buildPasswordFields(String plainPassword,
      {int? iterations}) {
    final hashed =
        _passwordService.hashPassword(plainPassword, iterations: iterations);
    return {
      // Keep password column for backward compatibility with old schema/logic.
      'password': hashed.hashBase64,
      'password_hash': hashed.hashBase64,
      'password_salt': hashed.saltBase64,
      'password_algo': hashed.algorithm,
      'password_iterations': hashed.iterations,
    };
  }

  Future<void> _normalizeBootstrapUsersForWeb(Database db) async {
    if (!kIsWeb) {
      return;
    }

    final recommendedIterations = _passwordService.recommendedIterations;
    final defaults = {
      for (final u in UserModel.getDefaultUsers())
        u.username.toLowerCase(): u.password,
    };
    if (defaults.isEmpty) {
      return;
    }

    final placeholders = List.filled(defaults.length, '?').join(', ');
    final rows = await db.query(
      'users',
      columns: ['id', 'username', 'password_iterations', 'last_login'],
      where: 'LOWER(username) IN ($placeholders)',
      whereArgs: defaults.keys.toList(),
    );

    for (final row in rows) {
      final userId = row['id'] as int;
      final username = (row['username'] ?? '').toString().toLowerCase();
      final defaultPassword = defaults[username];
      if (defaultPassword == null) {
        continue;
      }

      final iterations = row['password_iterations'] is int
          ? row['password_iterations'] as int
          : int.tryParse((row['password_iterations'] ?? '0').toString()) ?? 0;
      if (iterations <= 0 || iterations > recommendedIterations) {
        await db.update(
          'users',
          _buildPasswordFields(defaultPassword,
              iterations: recommendedIterations),
          where: 'id = ?',
          whereArgs: [userId],
        );
      }
    }
  }

  bool _verifyPasswordFromRow(Map<String, dynamic> row, String plainPassword) {
    final passwordHash = (row['password_hash'] ?? '').toString();
    final passwordSalt = (row['password_salt'] ?? '').toString();
    final passwordAlgo = (row['password_algo'] ?? '').toString();
    final iterations = row['password_iterations'] is int
        ? row['password_iterations'] as int
        : int.tryParse((row['password_iterations'] ?? '0').toString()) ?? 0;

    if (passwordHash.isNotEmpty &&
        passwordSalt.isNotEmpty &&
        passwordAlgo.isNotEmpty) {
      return _passwordService.verifyPassword(
        plainPassword: plainPassword,
        saltBase64: passwordSalt,
        storedHashBase64: passwordHash,
        storedAlgorithm: passwordAlgo,
        iterations: iterations,
      );
    }

    // Fail-closed: a row without hash/salt/algo cannot be authenticated.
    // The previous implementation accepted a plaintext password when the
    // hashed columns were missing, which made it possible for any row
    // bootstrapped with the legacy `password` column to bypass PBKDF2.
    // Every existing user has been re-hashed by `_upgradeStoredPasswords`
    // and the seed migrations, so an absent hash now genuinely indicates
    // a corrupt row that must NOT log in.
    return false;
  }

  /// Returns the usernames whose stored PBKDF2 hash still matches the
  /// well-known seed password for that account (e.g. `admin/admin123`).
  ///
  /// Used by the server's startup banner to emit a CRITICAL warning when
  /// production has drifted back to a default credential — typically after
  /// a data-volume migration silently re-seeded the row but the operator's
  /// `INITIAL_CREDENTIALS.txt` was preserved, so `bootstrap.sh` skipped
  /// re-rotation. Read-only: never mutates the database.
  Future<List<String>> findUsersWithDefaultSeedPasswords() async {
    final db = await database;
    final defaults = UserModel.getDefaultUsers();
    if (defaults.isEmpty) {
      return const [];
    }
    final placeholders = List.filled(defaults.length, '?').join(', ');
    final rows = await db.query(
      'users',
      columns: [
        'username',
        'password_hash',
        'password_salt',
        'password_algo',
        'password_iterations',
      ],
      where: 'LOWER(username) IN ($placeholders)',
      whereArgs:
          defaults.map((u) => u.username.toLowerCase()).toList(growable: false),
    );
    final byUsername = <String, UserModel>{
      for (final u in defaults) u.username.toLowerCase(): u,
    };
    final findings = <String>[];
    for (final row in rows) {
      final username = (row['username'] ?? '').toString();
      final seed = byUsername[username.toLowerCase()];
      if (seed == null) continue;
      if (_verifyPasswordFromRow(row, seed.password)) {
        findings.add(username);
      }
    }
    return findings;
  }

  Future<int> _insertUserInternal(Database db, UserModel user) async {
    final map = user.toMap(includePassword: false)..remove('id');
    map.addAll(_buildPasswordFields(user.password));
    return db.insert('users', map);
  }

  UserModel _sanitizeUser(UserModel user) {
    return user.copyWith(password: '');
  }

  Future<void> _ensureUniqueQaidIndexes(Database db) async {
    await _createUniqueQaidIndex(
      db,
      table: 'warid',
      indexName: 'idx_warid_qaid_number_unique',
    );
    await _createUniqueQaidIndex(
      db,
      table: 'sadir',
      indexName: 'idx_sadir_qaid_number_unique',
    );
  }

  Future<void> _ensurePerformanceIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_warid_qaid_date ON warid (qaid_date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sadir_qaid_date ON sadir (qaid_date DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_deleted_records_deleted_at ON deleted_records (deleted_at DESC)',
    );
  }

  Future<void> _createUniqueQaidIndex(
    Database db, {
    required String table,
    required String indexName,
  }) async {
    try {
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS $indexName ON $table (qaid_number)',
      );
    } catch (e) {
      // If duplicates already exist in old data, keep app-level checks active.
      _debugLog('could not create index $indexName: $e');
    }
  }

  String _normalizeQaidNumber(String value) {
    var normalized = value.trim().replaceAll(RegExp(r'\s+'), '');
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternArabicIndic = '۰۱۲۳۴۵۶۷۸۹';
    for (var i = 0; i < 10; i++) {
      normalized = normalized.replaceAll(arabicIndic[i], '$i');
      normalized = normalized.replaceAll(easternArabicIndic[i], '$i');
    }
    return normalized;
  }

  bool _isNumericQaidNumber(String value) {
    return RegExp(r'^\d+$').hasMatch(value);
  }

  Future<String> _validateAndNormalizeQaidNumber(
    Database db, {
    required String table,
    required String qaidNumber,
    int? excludeId,
  }) async {
    final normalizedQaid = _normalizeQaidNumber(qaidNumber);
    if (normalizedQaid.isEmpty) {
      throw StateError(
          '\u0631\u0642\u0645 \u0627\u0644\u0642\u064a\u062f \u0645\u0637\u0644\u0648\u0628.');
    }
    if (!_isNumericQaidNumber(normalizedQaid)) {
      throw StateError(
          '\u0631\u0642\u0645 \u0627\u0644\u0642\u064a\u062f \u064a\u062c\u0628 \u0623\u0646 \u064a\u062d\u062a\u0648\u064a \u0639\u0644\u0649 \u0623\u0631\u0642\u0627\u0645 \u0641\u0642\u0637.');
    }

    var whereClause = 'qaid_number = ?';
    final whereArgs = <Object>[normalizedQaid];
    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final duplicate = await _withWebTimeout(
      db.query(
        table,
        columns: ['id'],
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      ),
    );

    if (duplicate.isNotEmpty) {
      throw StateError(
          '\u0631\u0642\u0645 \u0627\u0644\u0642\u064a\u062f $normalizedQaid \u0645\u0633\u062c\u0644 \u0628\u0627\u0644\u0641\u0639\u0644 \u0648\u0644\u0627 \u064a\u0645\u0643\u0646 \u062a\u0643\u0631\u0627\u0631\u0647.');
    }

    // Secondary check to catch legacy records saved with spaces or
    // Arabic / Eastern Arabic-Indic digits. The previous version fetched
    // every row in the table into Dart memory and normalised in a loop —
    // O(N) per insert/update, O(N²) on large imports (§6.1). Two-stage
    // optimisation:
    //
    //   1. Push the "is this row dirty?" decision into SQL using GLOB
    //      and TRIM, so SQLite returns only rows that *might* clash with
    //      the normalised value. A clean numeric column returns zero
    //      rows directly from the engine.
    //   2. Cache the "table is clean" verdict in [_qaidNumberCleanTables]
    //      after the first all-clean scan. Subsequent inserts skip the
    //      query entirely and rely on the unique index alone.
    //
    // The fallback semantics are unchanged: a dirty row whose normalised
    // form matches still raises the same StateError.
    if (!_qaidNumberCleanTables.contains(table)) {
      final dirtyWhereParts = <String>[
        // Anything outside the ASCII digit set OR with whitespace at the
        // edges is potentially non-canonical and worth re-checking.
        "(qaid_number GLOB '*[^0-9]*' OR qaid_number != TRIM(qaid_number))",
      ];
      final dirtyWhereArgs = <Object>[];
      if (excludeId != null) {
        dirtyWhereParts.add('id != ?');
        dirtyWhereArgs.add(excludeId);
      }
      final dirtyWhere = dirtyWhereParts.join(' AND ');

      final dirtyRows = await _withWebTimeout(
        db.query(
          table,
          columns: ['id', 'qaid_number'],
          where: dirtyWhere,
          whereArgs: dirtyWhereArgs.isEmpty ? null : dirtyWhereArgs,
        ),
      );

      var hadDirtyRow = false;
      for (final row in dirtyRows) {
        hadDirtyRow = true;
        final existing =
            _normalizeQaidNumber((row['qaid_number'] ?? '').toString());
        if (existing == normalizedQaid) {
          throw StateError(
              '\u0631\u0642\u0645 \u0627\u0644\u0642\u064a\u062f $normalizedQaid \u0645\u0633\u062c\u0644 \u0628\u0627\u0644\u0641\u0639\u0644 \u0648\u0644\u0627 \u064a\u0645\u0643\u0646 \u062a\u0643\u0631\u0627\u0631\u0647.');
        }
      }

      // No dirty rows seen for this table → unique index is now
      // sufficient for future calls. We only promote the cache on the
      // insert path (excludeId == null), because an update call's
      // dirty scan deliberately filters out the row being updated:
      // if that row was the *only* dirty one, hadDirtyRow would still
      // be false, and a subsequent insert for a different qaid_number
      // could skip the legacy check while the dirty row is still
      // sitting in the table. Insert calls scan every row and produce
      // a sound clean verdict.
      if (!hadDirtyRow && excludeId == null) {
        _qaidNumberCleanTables.add(table);
      }
    }

    return normalizedQaid;
  }

  // ==================== USER OPERATIONS ====================

  Future<UserModel?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await _withWebTimeout(
      db.query(
        'users',
        where: 'username = ? COLLATE NOCASE',
        whereArgs: [username],
        limit: 1,
      ),
    );

    if (maps.isEmpty) {
      return null;
    }
    return _sanitizeUser(UserModel.fromMap(maps.first));
  }

  Future<UserModel?> authenticateUser(String username, String password) async {
    try {
      _debugLog('authenticate start for user=$username');
      final db = await _withWebTimeout(database);
      _debugLog('authenticate got database handle');
      final maps = await _withWebTimeout(
        db.query(
          'users',
          where: 'username = ? COLLATE NOCASE AND is_active = 1',
          whereArgs: [username],
          limit: 1,
        ),
      );
      _debugLog('authenticate user query done (count=${maps.length})');

      if (maps.isEmpty) {
        return null;
      }

      final row = maps.first;
      final iterations = row['password_iterations'] is int
          ? row['password_iterations'] as int
          : int.tryParse((row['password_iterations'] ?? '0').toString()) ?? 0;

      // PBKDF2 verification is the *only* path. The previous code had a
      // `useFastPath` branch that accepted the well-known seed password
      // (e.g. `admin123`, `user123`) on web even after rotation, allowing a
      // rotated default password to be silently reset back to the seed.
      // After PR #6's `harden_seeded_users` rotates seeds at deploy time,
      // any login attempt with the seed value must be rejected.
      _debugLog('authenticate verify hash start');
      final isValid = _verifyPasswordFromRow(row, password);
      _debugLog('authenticate verify hash done valid=$isValid');
      if (!isValid) {
        return null;
      }

      final userId = row['id'] as int;

      // Iteration-count alignment for the current platform.
      //
      // The web build historically stored 1,000 PBKDF2 iterations to keep
      // login latency acceptable in CanvasKit; the new default is 100,000
      // (OWASP 2024 minimum for PBKDF2-SHA256). Native always stores
      // 120,000. On a successful login we opportunistically re-hash so
      // the row converges on the recommended count for the platform that
      // just authenticated:
      //
      //   * Web sees a row at 1,000 iterations  → upgrade to 100,000 so
      //     the stored hash actually meets modern guidance.
      //   * Web sees a row at 120,000 (native)  → downgrade to 100,000 so
      //     subsequent web logins stay snappy. Still well above the
      //     OWASP threshold, no security regression.
      //   * Native sees a row at < 120,000     → upgrade to 120,000.
      //
      // We never re-hash on a row that's already at the recommended
      // count, and we read+verify with the *stored* iteration count
      // (the variable `iterations` above), so this is fully backward-
      // compatible with every existing row.
      final recommended = _passwordService.recommendedIterations;
      if (iterations != recommended) {
        _debugLog(
          'authenticate adjusting PBKDF2 iterations '
          '$iterations -> $recommended (kIsWeb=$kIsWeb)',
        );
        await _withWebTimeout(
          db.update(
            'users',
            _buildPasswordFields(password, iterations: recommended),
            where: 'id = ?',
            whereArgs: [userId],
          ),
        );
      }

      await _withWebTimeout(
        db.update(
          'users',
          {'last_login': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [userId],
        ),
      );

      final refreshed = await _withWebTimeout(
        db.query(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
          limit: 1,
        ),
      );
      _debugLog('authenticate success userId=$userId');
      if (refreshed.isEmpty) {
        return null;
      }

      return _sanitizeUser(UserModel.fromMap(refreshed.first));
    } catch (e) {
      _debugLog('authenticate failed: $e');
      if (kIsWeb && !_webRecoveryAttempted) {
        _webRecoveryAttempted = true;
        _debugLog('authenticate triggering web recovery');
        await _recoverWebDatabase();
        return authenticateUser(username, password);
      }
      rethrow;
    }
  }

  Future<void> _recoverWebDatabase() async {
    if (!kIsWeb) return;
    _debugLog('web recovery start');
    try {
      final db = _database;
      if (db != null) {
        await db.close();
      }
    } catch (_) {}
    _database = null;
    _qaidNumberCleanTables.clear();
    await _withWebTimeout(deleteDatabase('secretariat.db'));
    _database = await _withWebTimeout(_initDatabase());
    _debugLog('web recovery done');
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final maps = await db.query('users', orderBy: 'id ASC');
    return List.generate(
        maps.length, (i) => _sanitizeUser(UserModel.fromMap(maps[i])));
  }

  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return _withBusyRetry(() => _insertUserInternal(db, user));
  }

  Future<int> updateUser(UserModel user, {String? newPassword}) async {
    final db = await database;

    final data = user.toMap(includePassword: false);
    if (newPassword != null && newPassword.isNotEmpty) {
      data.addAll(_buildPasswordFields(newPassword));
    }

    return _withBusyRetry(
      () => db.update(
        'users',
        data,
        where: 'id = ?',
        whereArgs: [user.id],
      ),
    );
  }

  Future<int> updateUserPassword(int userId, String newPassword) async {
    final db = await database;
    return _withBusyRetry(
      () => db.update(
        'users',
        _buildPasswordFields(newPassword),
        where: 'id = ?',
        whereArgs: [userId],
      ),
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return _withBusyRetry(
      () => db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      ),
    );
  }

  // ==================== WARID OPERATIONS ====================

  Future<int> insertWarid(WaridModel warid) async {
    final db = await database;
    return _withBusyRetry(() async {
      final normalizedQaid = await _validateAndNormalizeQaidNumber(
        db,
        table: 'warid',
        qaidNumber: warid.qaidNumber,
      );
      final waridToSave = warid.copyWith(qaidNumber: normalizedQaid);
      final id = await db.insert('warid', waridToSave.toMap());
      await _logAudit('warid', id, 'INSERT', null, waridToSave.toMap(),
          warid.createdBy, warid.createdByName);
      return id;
    });
  }

  Future<int> updateWarid(WaridModel warid, int userId, String userName) async {
    final db = await database;
    return _withBusyRetry(() async {
      final normalizedQaid = await _validateAndNormalizeQaidNumber(
        db,
        table: 'warid',
        qaidNumber: warid.qaidNumber,
        excludeId: warid.id,
      );
      final waridToSave = warid.copyWith(qaidNumber: normalizedQaid);
      final oldData = await getWaridById(warid.id!);
      if (oldData == null) {
        throw StateError('السجل المطلوب غير موجود.');
      }

      _assertNoConcurrentRecordUpdate(
        currentUpdatedAt: oldData.updatedAt,
        incomingUpdatedAt: warid.updatedAt,
        documentType: 'الوارد',
        recordId: warid.id!,
      );

      final id = await db.update(
        'warid',
        {
          ...waridToSave.toMap(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [warid.id],
      );
      await _logAudit('warid', warid.id!, 'UPDATE', oldData.toMap(),
          waridToSave.toMap(), userId, userName);
      return id;
    });
  }

  Future<void> _archiveDeletedRecord(
    DatabaseExecutor executor, {
    required String documentType,
    required int originalRecordId,
    required Map<String, dynamic> payload,
    int? deletedBy,
    String? deletedByName,
  }) async {
    final archivedPayload = Map<String, dynamic>.from(payload)
      ..remove('id')
      ..remove('qaid_number')
      ..remove('updated_at');

    await executor.insert('deleted_records', {
      'document_type': _normalizeDocumentType(documentType),
      'original_record_id': originalRecordId,
      'archived_payload': jsonEncode(archivedPayload),
      'deleted_at': DateTime.now().toIso8601String(),
      'deleted_by': deletedBy,
      'deleted_by_name': deletedByName,
      'is_restored': 0,
    });
  }

  Future<int> deleteWarid(int id, int userId, String userName) async {
    final db = await database;
    final oldData = await getWaridById(id);
    return _withBusyRetry(() async {
      final result = await db.transaction((txn) async {
        if (oldData != null) {
          await _archiveDeletedRecord(
            txn,
            documentType: 'warid',
            originalRecordId: id,
            payload: oldData.toMap(),
            deletedBy: userId,
            deletedByName: userName,
          );
        }

        return txn.delete(
          'warid',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      await _logAudit(
          'warid', id, 'DELETE', oldData?.toMap(), null, userId, userName);
      return result;
    });
  }

  Future<WaridModel?> getWaridById(int id) async {
    final db = await database;
    final maps = await db.query(
      'warid',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return WaridModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<WaridModel>> getAllWarid({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? externalNumber,
    DateTime? externalDate,
    String? chairmanIncomingNumber,
    DateTime? chairmanIncomingDate,
    String? chairmanReturnNumber,
    DateTime? chairmanReturnDate,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <dynamic>[];

    final trimmedSearch = search?.trim() ?? '';
    if (trimmedSearch.isNotEmpty) {
      whereParts.add(
          '''(qaid_number LIKE ? OR subject LIKE ? OR source_administration LIKE ?
        OR letter_number LIKE ? OR chairman_incoming_number LIKE ? OR chairman_return_number LIKE ?
        OR recipient_1_name LIKE ? OR recipient_2_name LIKE ? OR recipient_3_name LIKE ?
        OR letter_date LIKE ? OR chairman_incoming_date LIKE ? OR chairman_return_date LIKE ?
        OR file_name LIKE ?)''');
      final searchPattern = '%$trimmedSearch%';
      whereArgs.addAll(List.filled(13, searchPattern));
    }

    if (fromDate != null) {
      whereParts.add('qaid_date >= ?');
      whereArgs.add(fromDate.toIso8601String());
    }

    if (toDate != null) {
      whereParts.add('qaid_date <= ?');
      whereArgs.add(toDate.toIso8601String());
    }

    final trimmedExternalNumber = externalNumber?.trim() ?? '';
    if (trimmedExternalNumber.isNotEmpty) {
      whereParts.add('letter_number LIKE ?');
      whereArgs.add('%$trimmedExternalNumber%');
    }

    if (externalDate != null) {
      whereParts.add('date(letter_date) = date(?)');
      whereArgs.add(externalDate.toIso8601String());
    }

    final trimmedChairmanIncomingNumber = chairmanIncomingNumber?.trim() ?? '';
    if (trimmedChairmanIncomingNumber.isNotEmpty) {
      whereParts.add('chairman_incoming_number LIKE ?');
      whereArgs.add('%$trimmedChairmanIncomingNumber%');
    }

    if (chairmanIncomingDate != null) {
      whereParts.add('date(chairman_incoming_date) = date(?)');
      whereArgs.add(chairmanIncomingDate.toIso8601String());
    }

    final trimmedChairmanReturnNumber = chairmanReturnNumber?.trim() ?? '';
    if (trimmedChairmanReturnNumber.isNotEmpty) {
      whereParts.add('chairman_return_number LIKE ?');
      whereArgs.add('%$trimmedChairmanReturnNumber%');
    }

    if (chairmanReturnDate != null) {
      whereParts.add('date(chairman_return_date) = date(?)');
      whereArgs.add(chairmanReturnDate.toIso8601String());
    }

    final maps = await db.query(
      'warid',
      where: whereParts.isNotEmpty ? whereParts.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'qaid_date DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) => WaridModel.fromMap(maps[i]));
  }

  Future<int> getWaridCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM warid');
    return result.first['count'] as int;
  }

  Future<int> insertWaridFromImport(WaridModel warid,
      {int? importFileId}) async {
    final db = await database;
    final normalizedQaid = await _validateAndNormalizeQaidNumber(
      db,
      table: 'warid',
      qaidNumber: warid.qaidNumber,
    );
    final data = warid.copyWith(qaidNumber: normalizedQaid).toMap()
      ..remove('id');
    data['import_file_id'] = importFileId;
    final id = await db.insert('warid', data);
    await _logAudit('warid', id, 'IMPORT', null, data, warid.createdBy,
        warid.createdByName);
    return id;
  }

  // ==================== SADIR OPERATIONS ====================

  Future<int> insertSadir(SadirModel sadir) async {
    final db = await database;
    return _withBusyRetry(() async {
      final normalizedQaid = await _validateAndNormalizeQaidNumber(
        db,
        table: 'sadir',
        qaidNumber: sadir.qaidNumber,
      );
      final sadirToSave = sadir.copyWith(qaidNumber: normalizedQaid);
      final id = await db.insert('sadir', sadirToSave.toMap());
      await _logAudit('sadir', id, 'INSERT', null, sadirToSave.toMap(),
          sadir.createdBy, sadir.createdByName);
      return id;
    });
  }

  Future<int> updateSadir(SadirModel sadir, int userId, String userName) async {
    final db = await database;
    return _withBusyRetry(() async {
      final normalizedQaid = await _validateAndNormalizeQaidNumber(
        db,
        table: 'sadir',
        qaidNumber: sadir.qaidNumber,
        excludeId: sadir.id,
      );
      final sadirToSave = sadir.copyWith(qaidNumber: normalizedQaid);
      final oldData = await getSadirById(sadir.id!);
      if (oldData == null) {
        throw StateError('السجل المطلوب غير موجود.');
      }

      _assertNoConcurrentRecordUpdate(
        currentUpdatedAt: oldData.updatedAt,
        incomingUpdatedAt: sadir.updatedAt,
        documentType: 'الصادر',
        recordId: sadir.id!,
      );

      final id = await db.update(
        'sadir',
        {
          ...sadirToSave.toMap(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [sadir.id],
      );
      await _logAudit('sadir', sadir.id!, 'UPDATE', oldData.toMap(),
          sadirToSave.toMap(), userId, userName);
      return id;
    });
  }

  Future<int> deleteSadir(int id, int userId, String userName) async {
    final db = await database;
    final oldData = await getSadirById(id);
    return _withBusyRetry(() async {
      final result = await db.transaction((txn) async {
        if (oldData != null) {
          await _archiveDeletedRecord(
            txn,
            documentType: 'sadir',
            originalRecordId: id,
            payload: oldData.toMap(),
            deletedBy: userId,
            deletedByName: userName,
          );
        }

        return txn.delete(
          'sadir',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      await _logAudit(
          'sadir', id, 'DELETE', oldData?.toMap(), null, userId, userName);
      return result;
    });
  }

  Future<SadirModel?> getSadirById(int id) async {
    final db = await database;
    final maps = await db.query(
      'sadir',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SadirModel.fromMap(maps.first);
    }
    return null;
  }

  Future<List<SadirModel>> getAllSadir({
    String? search,
    DateTime? fromDate,
    DateTime? toDate,
    String? externalNumber,
    DateTime? externalDate,
    String? chairmanIncomingNumber,
    DateTime? chairmanIncomingDate,
    String? chairmanReturnNumber,
    DateTime? chairmanReturnDate,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <dynamic>[];

    final trimmedSearch = search?.trim() ?? '';
    if (trimmedSearch.isNotEmpty) {
      whereParts.add(
          '''(qaid_number LIKE ? OR subject LIKE ? OR destination_administration LIKE ?
        OR letter_number LIKE ? OR chairman_incoming_number LIKE ? OR chairman_return_number LIKE ?
        OR sent_to_1_name LIKE ? OR sent_to_2_name LIKE ? OR sent_to_3_name LIKE ?
        OR letter_date LIKE ? OR chairman_incoming_date LIKE ? OR chairman_return_date LIKE ?
        OR file_name LIKE ?)''');
      final searchPattern = '%$trimmedSearch%';
      whereArgs.addAll(List.filled(13, searchPattern));
    }

    if (fromDate != null) {
      whereParts.add('qaid_date >= ?');
      whereArgs.add(fromDate.toIso8601String());
    }

    if (toDate != null) {
      whereParts.add('qaid_date <= ?');
      whereArgs.add(toDate.toIso8601String());
    }

    final trimmedExternalNumber = externalNumber?.trim() ?? '';
    if (trimmedExternalNumber.isNotEmpty) {
      whereParts.add('letter_number LIKE ?');
      whereArgs.add('%$trimmedExternalNumber%');
    }

    if (externalDate != null) {
      whereParts.add('date(letter_date) = date(?)');
      whereArgs.add(externalDate.toIso8601String());
    }

    final trimmedChairmanIncomingNumber = chairmanIncomingNumber?.trim() ?? '';
    if (trimmedChairmanIncomingNumber.isNotEmpty) {
      whereParts.add('chairman_incoming_number LIKE ?');
      whereArgs.add('%$trimmedChairmanIncomingNumber%');
    }

    if (chairmanIncomingDate != null) {
      whereParts.add('date(chairman_incoming_date) = date(?)');
      whereArgs.add(chairmanIncomingDate.toIso8601String());
    }

    final trimmedChairmanReturnNumber = chairmanReturnNumber?.trim() ?? '';
    if (trimmedChairmanReturnNumber.isNotEmpty) {
      whereParts.add('chairman_return_number LIKE ?');
      whereArgs.add('%$trimmedChairmanReturnNumber%');
    }

    if (chairmanReturnDate != null) {
      whereParts.add('date(chairman_return_date) = date(?)');
      whereArgs.add(chairmanReturnDate.toIso8601String());
    }

    final maps = await db.query(
      'sadir',
      where: whereParts.isNotEmpty ? whereParts.join(' AND ') : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'qaid_date DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) => SadirModel.fromMap(maps[i]));
  }

  Future<int> getSadirCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sadir');
    return result.first['count'] as int;
  }

  Future<int> insertSadirFromImport(SadirModel sadir,
      {int? importFileId}) async {
    final db = await database;
    final normalizedQaid = await _validateAndNormalizeQaidNumber(
      db,
      table: 'sadir',
      qaidNumber: sadir.qaidNumber,
    );
    final data = sadir.copyWith(qaidNumber: normalizedQaid).toMap()
      ..remove('id');
    data['import_file_id'] = importFileId;
    final id = await db.insert('sadir', data);
    await _logAudit('sadir', id, 'IMPORT', null, data, sadir.createdBy,
        sadir.createdByName);
    return id;
  }

  Future<List<DeletedRecordModel>> getDeletedRecords({
    String? documentType,
    bool includeRestored = false,
    String? search,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <Object>[];

    if (documentType != null && documentType.trim().isNotEmpty) {
      whereParts.add('document_type = ?');
      whereArgs.add(_normalizeDocumentType(documentType));
    }

    if (!includeRestored) {
      whereParts.add('is_restored = 0');
    }

    final trimmedSearch = search?.trim() ?? '';
    if (trimmedSearch.isNotEmpty) {
      whereParts.add(
          '(archived_payload LIKE ? OR deleted_by_name LIKE ? OR document_type LIKE ?)');
      final searchPattern = '%$trimmedSearch%';
      whereArgs.add(searchPattern);
      whereArgs.add(searchPattern);
      whereArgs.add(searchPattern);
    }

    final rows = await db.query(
      'deleted_records',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'deleted_at DESC',
      limit: limit,
      offset: offset,
    );

    return rows.map(DeletedRecordModel.fromMap).toList();
  }

  Future<int> restoreDeletedRecord({
    required int deletedRecordId,
    required String qaidNumber,
    required int userId,
    required String userName,
  }) async {
    final db = await database;
    final deletedRows = await db.query(
      'deleted_records',
      where: 'id = ? AND is_restored = 0',
      whereArgs: [deletedRecordId],
      limit: 1,
    );
    if (deletedRows.isEmpty) {
      throw StateError('السجل غير متاح للاسترجاع أو تم استرجاعه مسبقًا.');
    }

    final deletedRecord = DeletedRecordModel.fromMap(deletedRows.first);
    return restoreDeletedRecordWithPayload(
      deletedRecordId: deletedRecordId,
      documentType: deletedRecord.documentType,
      payload: deletedRecord.archivedPayload,
      qaidNumber: qaidNumber,
      userId: userId,
      userName: userName,
      auditAction: 'RESTORE',
    );
  }

  Future<int> restoreDeletedRecordWithPayload({
    required int deletedRecordId,
    required String documentType,
    required Map<String, dynamic> payload,
    required String qaidNumber,
    required int userId,
    required String userName,
    String auditAction = 'RESTORE_EDIT',
  }) async {
    final db = await database;
    final deletedRows = await db.query(
      'deleted_records',
      where: 'id = ? AND is_restored = 0',
      whereArgs: [deletedRecordId],
      limit: 1,
    );

    if (deletedRows.isEmpty) {
      throw StateError('السجل غير متاح للاسترجاع أو تم استرجاعه مسبقًا.');
    }

    final deletedRecord = DeletedRecordModel.fromMap(deletedRows.first);
    final tableName = _normalizeDocumentType(documentType);
    if (tableName != _normalizeDocumentType(deletedRecord.documentType)) {
      throw StateError('نوع السجل المحدد لا يطابق السجل المحذوف.');
    }

    final normalizedQaid = await _validateAndNormalizeQaidNumber(
      db,
      table: tableName,
      qaidNumber: qaidNumber,
    );

    final restoredPayload = Map<String, dynamic>.from(payload)
      ..remove('id')
      ..remove('qaid_number')
      ..['qaid_number'] = normalizedQaid;
    final nowIso = DateTime.now().toIso8601String();
    restoredPayload['created_at'] ??=
        deletedRecord.archivedPayload['created_at'] ?? nowIso;
    restoredPayload['updated_at'] = nowIso;

    late final int restoredId;
    await db.transaction((txn) async {
      final lockRows = await txn.query(
        'deleted_records',
        columns: ['id', 'is_restored'],
        where: 'id = ?',
        whereArgs: [deletedRecordId],
        limit: 1,
      );
      if (lockRows.isEmpty) {
        throw StateError('تعذر العثور على السجل المحذوف.');
      }
      if ((lockRows.first['is_restored'] as int? ?? 0) == 1) {
        throw StateError('تم استرجاع هذا السجل مسبقًا.');
      }

      restoredId = await txn.insert(tableName, restoredPayload);
      await txn.update(
        'deleted_records',
        {
          'is_restored': 1,
          'restored_at': nowIso,
          'restored_by': userId,
          'restored_by_name': userName,
          'restored_record_id': restoredId,
        },
        where: 'id = ?',
        whereArgs: [deletedRecordId],
      );
    });

    await _logAudit(
      tableName,
      restoredId,
      auditAction,
      null,
      restoredPayload,
      userId,
      userName,
    );
    return restoredId;
  }

  Future<int> createImportFileRecord({
    required String documentType,
    required String fileName,
    String? filePath,
    required Uint8List fileBytes,
    required int totalRows,
    int? importedBy,
    String? importedByName,
  }) async {
    final db = await database;
    return db.insert('import_files', {
      'document_type': documentType,
      'file_name': fileName,
      'file_path': filePath,
      // Keeping large file bytes in DB duplicates memory/disk usage with no read path.
      'file_bytes': null,
      'total_rows': totalRows,
      'imported_rows': 0,
      'failed_rows': totalRows,
      'imported_by': importedBy,
      'imported_by_name': importedByName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> finalizeImportFileRecord(
    int importFileId, {
    required int importedRows,
    required int failedRows,
  }) async {
    final db = await database;
    await db.update(
      'import_files',
      {
        'imported_rows': importedRows,
        'failed_rows': failedRows,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [importFileId],
    );
  }

  // ==================== AUDIT LOG ====================

  Future<void> _logAudit(
    String tableName,
    int recordId,
    String action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    int? userId,
    String? userName,
  ) async {
    final db = await database;
    await db.insert('audit_log', {
      'table_name': tableName,
      'record_id': recordId,
      'action': action,
      'old_values': oldValues?.toString(),
      'new_values': newValues?.toString(),
      'user_id': userId,
      'user_name': userName,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAuditLog(
      {int? recordId, String? tableName}) async {
    final db = await database;
    var whereClause = '';
    final whereArgs = <dynamic>[];

    if (recordId != null) {
      whereClause = 'record_id = ?';
      whereArgs.add(recordId);
    }

    if (tableName != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'table_name = ?';
      whereArgs.add(tableName);
    }

    return db.query(
      'audit_log',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );
  }

  // ==================== STATISTICS ====================

  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;

    final waridCount = await getWaridCount();
    final sadirCount = await getSadirCount();

    final waridFollowup = await db.rawQuery(
        'SELECT COUNT(*) as count FROM warid WHERE needs_followup = 1');
    final sadirFollowup = await db.rawQuery(
        'SELECT COUNT(*) as count FROM sadir WHERE needs_followup = 1');

    final waridThisMonth = await db.rawQuery('''
      SELECT COUNT(*) as count FROM warid
      WHERE strftime('%Y-%m', qaid_date) = strftime('%Y-%m', 'now')
    ''');
    final sadirThisMonth = await db.rawQuery('''
      SELECT COUNT(*) as count FROM sadir
      WHERE strftime('%Y-%m', qaid_date) = strftime('%Y-%m', 'now')
    ''');

    return {
      'warid_total': waridCount,
      'sadir_total': sadirCount,
      'warid_followup': waridFollowup.first['count'],
      'sadir_followup': sadirFollowup.first['count'],
      'warid_this_month': waridThisMonth.first['count'],
      'sadir_this_month': sadirThisMonth.first['count'],
      'total_documents': waridCount + sadirCount,
    };
  }

  Future<void> close() async {
    await resetConnection();
  }

  Future<void> resetConnection() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
    _webRecoveryAttempted = false;
    _qaidNumberCleanTables.clear();
  }
}
