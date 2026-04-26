import 'dart:io';

import 'package:railway_secretariat/core/platform/foundation_shims.dart'
    if (dart.library.ui) 'package:flutter/foundation.dart'
    show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:railway_secretariat/core/platform/path_provider_shims.dart'
    if (dart.library.ui) 'package:path_provider/path_provider.dart';
import 'package:railway_secretariat/core/platform/shared_preferences_shims.dart'
    if (dart.library.ui) 'package:shared_preferences/shared_preferences.dart';

class StorageReconfigureResult {
  final String oldRoot;
  final String newRoot;
  final bool sameRoot;
  final bool databaseCopied;
  final bool attachmentsCopied;
  final bool databaseAlreadyExists;

  const StorageReconfigureResult({
    required this.oldRoot,
    required this.newRoot,
    required this.sameRoot,
    required this.databaseCopied,
    required this.attachmentsCopied,
    required this.databaseAlreadyExists,
  });
}

class StorageLocationService {
  static const String _storageRootKey = 'secretariat_storage_root';
  static const String _envStorageRootKey = 'SECRETARIAT_STORAGE_ROOT';
  static const String _databaseFileName = 'secretariat.db';
  static const String _attachmentsDirectoryName = 'attachments';

  static final StorageLocationService _instance =
      StorageLocationService._internal();

  String? _cachedStorageRoot;

  factory StorageLocationService() => _instance;

  StorageLocationService._internal();

  Future<String> resolveStorageRoot() async {
    if (kIsWeb) {
      return 'web_storage';
    }

    if (_cachedStorageRoot != null && _cachedStorageRoot!.trim().isNotEmpty) {
      return _cachedStorageRoot!;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_storageRootKey)?.trim();
    final envPath = Platform.environment[_envStorageRootKey]?.trim();
    final defaultPath = await getDefaultStorageRoot();

    for (final candidate in <String?>[savedPath, envPath, defaultPath]) {
      final normalized = _normalizePath(candidate);
      if (normalized == null) {
        continue;
      }

      try {
        await Directory(normalized).create(recursive: true);
        _cachedStorageRoot = normalized;
        return normalized;
      } catch (_) {
        // Try next candidate.
      }
    }

    throw const FileSystemException('تعذر تحديد مسار تخزين صالح للبيانات');
  }

  Future<String?> getCustomStorageRoot() async {
    if (kIsWeb) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    return _normalizePath(prefs.getString(_storageRootKey));
  }

  Future<String> getDefaultStorageRoot() async {
    if (kIsWeb) {
      return 'web_storage';
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final executablePath = Platform.resolvedExecutable;
      final executableName = p.basename(executablePath).toLowerCase();
      final looksLikeRuntimeBinary = executableName == 'dart' ||
          executableName == 'dart.exe' ||
          executableName.startsWith('flutter');

      final basePath = looksLikeRuntimeBinary
          ? Directory.current.path
          : File(executablePath).parent.path;
      return _normalizePath(p.join(basePath, 'secretariat_data'))!;
    }

    final appSupportDirectory = await getApplicationSupportDirectory();
    return _normalizePath(
      p.join(appSupportDirectory.path, 'secretariat_data'),
    )!;
  }

  Future<String> getDatabasePath() async {
    final root = await resolveStorageRoot();
    return p.join(root, _databaseFileName);
  }

  Future<String> getAttachmentsRoot() async {
    final root = await resolveStorageRoot();
    return p.join(root, _attachmentsDirectoryName);
  }

  Future<StorageReconfigureResult> configureStorageRoot(
    String requestedRoot, {
    bool migrateExistingData = true,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('تغيير مسار التخزين غير مدعوم على الويب');
    }

    final normalizedRequested = _normalizePath(requestedRoot);
    if (normalizedRequested == null) {
      throw ArgumentError('مسار التخزين غير صالح');
    }

    await Directory(normalizedRequested).create(recursive: true);

    final oldRoot = await resolveStorageRoot();
    final sameRoot = _isSamePath(oldRoot, normalizedRequested);
    var databaseCopied = false;
    var attachmentsCopied = false;
    var databaseAlreadyExists = false;

    if (!sameRoot && migrateExistingData) {
      final oldDbPath = p.join(oldRoot, _databaseFileName);
      final newDbPath = p.join(normalizedRequested, _databaseFileName);
      final oldDbFile = File(oldDbPath);
      final newDbFile = File(newDbPath);

      if (await oldDbFile.exists()) {
        if (await newDbFile.exists()) {
          databaseAlreadyExists = true;
        } else {
          await newDbFile.parent.create(recursive: true);
          await oldDbFile.copy(newDbPath);
          databaseCopied = true;
        }
      }

      final oldAttachmentsDir = Directory(
        p.join(oldRoot, _attachmentsDirectoryName),
      );
      final newAttachmentsDir = Directory(
        p.join(normalizedRequested, _attachmentsDirectoryName),
      );

      if (await oldAttachmentsDir.exists()) {
        await newAttachmentsDir.create(recursive: true);
        attachmentsCopied = await _copyDirectory(
          source: oldAttachmentsDir,
          destination: newAttachmentsDir,
        );
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageRootKey, normalizedRequested);
    _cachedStorageRoot = normalizedRequested;

    return StorageReconfigureResult(
      oldRoot: oldRoot,
      newRoot: normalizedRequested,
      sameRoot: sameRoot,
      databaseCopied: databaseCopied,
      attachmentsCopied: attachmentsCopied,
      databaseAlreadyExists: databaseAlreadyExists,
    );
  }

  Future<void> resetToDefaultStorageRoot({
    bool migrateExistingData = true,
  }) async {
    if (kIsWeb) {
      return;
    }

    final defaultRoot = await getDefaultStorageRoot();
    await configureStorageRoot(
      defaultRoot,
      migrateExistingData: migrateExistingData,
    );
  }

  void clearCache() {
    _cachedStorageRoot = null;
  }

  String? _normalizePath(String? rawPath) {
    final trimmed = rawPath?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }

    var normalized = p.normalize(p.absolute(trimmed));
    if (!kIsWeb && Platform.isWindows) {
      normalized = normalized.replaceAll('/', '\\');
    }
    return normalized;
  }

  bool _isSamePath(String first, String second) {
    var left = first;
    var right = second;
    if (!kIsWeb && Platform.isWindows) {
      left = left.toLowerCase();
      right = right.toLowerCase();
    }
    return left == right;
  }

  Future<bool> _copyDirectory({
    required Directory source,
    required Directory destination,
  }) async {
    var copiedAnything = false;
    await for (final entity in source.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }

      final relativePath = p.relative(entity.path, from: source.path);
      final targetPath = p.join(destination.path, relativePath);
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        continue;
      }

      await targetFile.parent.create(recursive: true);
      await entity.copy(targetPath);
      copiedAnything = true;
    }
    return copiedAnything;
  }
}
