import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:railway_secretariat/core/platform/foundation_shims.dart'
    if (dart.library.ui) 'package:flutter/foundation.dart'
    show kIsWeb;
import 'package:path/path.dart' as p;

import 'package:railway_secretariat/core/network/api_client.dart';
import 'package:railway_secretariat/core/services/storage_location_service.dart';

class AttachmentStorageService {
  static final AttachmentStorageService _instance =
      AttachmentStorageService._internal();
  static final Random _random = Random();
  static const String _managedPathPrefix = 'managed://';
  static const String _apiBaseUrlEnvKey = 'SECRETARIAT_API_BASE_URL';
  static const String _remoteCacheDirectoryName = '_remote_cache';

  String? _attachmentsRootCache;
  ApiClient? _remoteApiClient;
  String? _remoteApiBaseUrl;
  final StorageLocationService _storageLocationService =
      StorageLocationService();

  factory AttachmentStorageService() => _instance;

  AttachmentStorageService._internal();

  Future<String?> storeAttachment({
    required String? sourcePath,
    required String originalFileName,
    required String documentType,
    bool isFollowup = false,
  }) async {
    final trimmedSourcePath = sourcePath?.trim() ?? '';
    if (trimmedSourcePath.isEmpty) {
      return null;
    }

    if (kIsWeb) {
      return trimmedSourcePath;
    }

    final sourceFile = File(trimmedSourcePath);
    if (!await sourceFile.exists()) {
      return null;
    }

    final remoteApiClient = _resolveRemoteApiClient();
    if (remoteApiClient != null) {
      try {
        final bytes = await sourceFile.readAsBytes();
        if (bytes.isEmpty) {
          return null;
        }
        final resolvedName = originalFileName.trim().isNotEmpty
            ? originalFileName.trim()
            : p.basename(trimmedSourcePath);
        return _uploadRemoteAttachment(
          apiClient: remoteApiClient,
          fileBytes: bytes,
          fileName: resolvedName,
          documentType: documentType,
          isFollowup: isFollowup,
        );
      } catch (_) {
        return null;
      }
    }

    final attachmentsRoot = await _resolveAttachmentsRoot();
    if (attachmentsRoot == null) {
      return null;
    }

    if (_isInsideDirectory(trimmedSourcePath, attachmentsRoot)) {
      return _toManagedPath(trimmedSourcePath, attachmentsRoot);
    }

    final resolvedName = originalFileName.trim().isNotEmpty
        ? originalFileName.trim()
        : p.basename(trimmedSourcePath);
    final targetPath = await _buildTargetPath(
      attachmentsRoot: attachmentsRoot,
      documentType: documentType,
      isFollowup: isFollowup,
      resolvedName: resolvedName,
    );

    if (_isSamePath(trimmedSourcePath, targetPath)) {
      return _toManagedPath(trimmedSourcePath, attachmentsRoot);
    }

    await sourceFile.copy(targetPath);
    return _toManagedPath(targetPath, attachmentsRoot);
  }

  Future<String?> storeAttachmentBytes({
    required Uint8List fileBytes,
    required String originalFileName,
    required String documentType,
    bool isFollowup = false,
  }) async {
    if (kIsWeb || fileBytes.isEmpty) {
      return null;
    }

    final attachmentsRoot = await _resolveAttachmentsRoot();
    if (attachmentsRoot == null) {
      return null;
    }

    final resolvedName = originalFileName.trim().isNotEmpty
        ? originalFileName.trim()
        : 'attachment_${DateTime.now().millisecondsSinceEpoch}.bin';
    final targetPath = await _buildTargetPath(
      attachmentsRoot: attachmentsRoot,
      documentType: documentType,
      isFollowup: isFollowup,
      resolvedName: resolvedName,
    );
    await File(targetPath).writeAsBytes(fileBytes, flush: true);
    return _toManagedPath(targetPath, attachmentsRoot);
  }

  Future<String?> resolveAttachmentPath(String? storedPath) async {
    final trimmedPath = storedPath?.trim() ?? '';
    if (trimmedPath.isEmpty) {
      return null;
    }

    if (kIsWeb) {
      return trimmedPath;
    }

    final attachmentsRoot = await _resolveAttachmentsRoot();
    if (attachmentsRoot == null) {
      return trimmedPath;
    }

    final resolvedPath =
        _resolveStoredPathToAbsolute(trimmedPath, attachmentsRoot);
    if (File(resolvedPath).existsSync()) {
      return resolvedPath;
    }

    final remoteApiClient = _resolveRemoteApiClient();
    if (remoteApiClient != null && _isManagedPath(trimmedPath)) {
      final downloaded = await _downloadRemoteAttachmentToCache(
        apiClient: remoteApiClient,
        storedPath: trimmedPath,
        attachmentsRoot: attachmentsRoot,
      );
      if (downloaded != null) {
        return downloaded;
      }
    }

    return resolvedPath;
  }

  Future<void> deleteManagedFileIfOwned(
    String? candidatePath, {
    String? exceptPath,
  }) async {
    if (kIsWeb) {
      return;
    }

    final trimmedCandidatePath = candidatePath?.trim() ?? '';
    if (_resolveRemoteApiClient() != null &&
        _isManagedPath(trimmedCandidatePath)) {
      return;
    }

    final resolvedCandidate = await resolveAttachmentPath(candidatePath);
    if (resolvedCandidate == null || resolvedCandidate.trim().isEmpty) {
      return;
    }

    final resolvedExcept = await resolveAttachmentPath(exceptPath);
    if (resolvedExcept != null &&
        _isSamePath(resolvedCandidate, resolvedExcept)) {
      return;
    }

    final attachmentsRoot = await _resolveAttachmentsRoot();
    if (attachmentsRoot == null ||
        !_isInsideDirectory(resolvedCandidate, attachmentsRoot)) {
      return;
    }

    try {
      final file = File(resolvedCandidate);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup failures to avoid breaking user flows.
    }
  }

  void clearCache() {
    _attachmentsRootCache = null;
    _remoteApiClient = null;
    _remoteApiBaseUrl = null;
  }

  Future<String?> _resolveAttachmentsRoot() async {
    if (_attachmentsRootCache != null && _attachmentsRootCache!.isNotEmpty) {
      return _attachmentsRootCache;
    }

    try {
      final attachmentsRoot =
          await _storageLocationService.getAttachmentsRoot();
      await Directory(attachmentsRoot).create(recursive: true);
      _attachmentsRootCache = attachmentsRoot;
      return attachmentsRoot;
    } catch (_) {
      return null;
    }
  }

  ApiClient? _resolveRemoteApiClient() {
    final baseUrl = _resolveRemoteApiBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      _remoteApiClient = null;
      _remoteApiBaseUrl = null;
      return null;
    }

    if (_remoteApiClient != null && _remoteApiBaseUrl == baseUrl) {
      return _remoteApiClient;
    }

    _remoteApiBaseUrl = baseUrl;
    _remoteApiClient = ApiClient(baseUrl: baseUrl);
    return _remoteApiClient;
  }

  String? _resolveRemoteApiBaseUrl() {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    final trimmedDefine = fromDefine.trim();
    if (trimmedDefine.isNotEmpty) {
      return trimmedDefine;
    }

    if (!kIsWeb) {
      final fromEnv = Platform.environment[_apiBaseUrlEnvKey]?.trim();
      if (fromEnv != null && fromEnv.isNotEmpty) {
        return fromEnv;
      }
    }
    return null;
  }

  Future<String?> _uploadRemoteAttachment({
    required ApiClient apiClient,
    required Uint8List fileBytes,
    required String fileName,
    required String documentType,
    required bool isFollowup,
  }) async {
    final response = await apiClient.postMap(
      '/api/attachments/upload',
      body: <String, dynamic>{
        'fileName': fileName,
        'documentType': documentType,
        'isFollowup': isFollowup ? 1 : 0,
        'fileBytesBase64': base64Encode(fileBytes),
      },
    );

    final storedPath = response['filePath']?.toString().trim() ?? '';
    if (storedPath.isEmpty) {
      return null;
    }
    return storedPath;
  }

  Future<String?> _downloadRemoteAttachmentToCache({
    required ApiClient apiClient,
    required String storedPath,
    required String attachmentsRoot,
  }) async {
    final cacheDirPath = joinPath(attachmentsRoot, _remoteCacheDirectoryName);
    final cacheDir = Directory(cacheDirPath);
    await cacheDir.create(recursive: true);

    final pathHash = _stablePathHash(storedPath);
    final storedExtension = p.extension(storedPath);
    final initialExtension = storedExtension.isEmpty ? '.bin' : storedExtension;
    var targetPath = joinPath(cacheDir.path, '$pathHash$initialExtension');
    if (File(targetPath).existsSync()) {
      return targetPath;
    }

    try {
      final response = await apiClient.postMap(
        '/api/attachments/download',
        body: <String, dynamic>{'filePath': storedPath},
      );
      final rawBase64 = response['fileBytesBase64']?.toString() ?? '';
      if (rawBase64.trim().isEmpty) {
        return null;
      }

      final bytes = base64Decode(rawBase64);
      if (bytes.isEmpty) {
        return null;
      }

      final serverFileName = response['fileName']?.toString().trim() ?? '';
      final serverExtension = p.extension(serverFileName);
      final preferredExtension =
          serverExtension.isEmpty ? initialExtension : serverExtension;
      targetPath = joinPath(cacheDir.path, '$pathHash$preferredExtension');

      await File(targetPath).writeAsBytes(bytes, flush: true);
      return targetPath;
    } catch (_) {
      return null;
    }
  }

  Future<String> _buildTargetPath({
    required String attachmentsRoot,
    required String documentType,
    required bool isFollowup,
    required String resolvedName,
  }) async {
    final normalizedType = _normalizeDocumentType(documentType);
    final section = isFollowup ? 'followup' : 'main';
    final targetDir =
        Directory(joinPath(attachmentsRoot, normalizedType, section));
    await targetDir.create(recursive: true);

    final extension = p.extension(resolvedName);
    final baseName = _sanitizeName(p.basenameWithoutExtension(resolvedName));
    final suffix =
        '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix(6)}';
    final targetFileName = baseName.isEmpty
        ? '$suffix$extension'
        : '${baseName}_$suffix$extension';
    return joinPath(targetDir.path, targetFileName);
  }

  String _stablePathHash(String value) {
    final bytes = utf8.encode(value);
    var hash = 0x811C9DC5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _resolveStoredPathToAbsolute(
      String storedPath, String attachmentsRoot) {
    if (_isManagedPath(storedPath)) {
      final managedRelative = storedPath
          .substring(_managedPathPrefix.length)
          .replaceAll('/', Platform.pathSeparator);
      final relativeNormalized = p.normalize(managedRelative);
      return p.normalize(p.join(attachmentsRoot, relativeNormalized));
    }

    final normalizedStoredPath = _normalizePath(storedPath);
    if (File(normalizedStoredPath).existsSync()) {
      return normalizedStoredPath;
    }

    final relativeFromAttachments = _extractRelativeFromAttachments(storedPath);
    if (relativeFromAttachments != null) {
      return p.normalize(p.join(attachmentsRoot, relativeFromAttachments));
    }

    if (!p.isAbsolute(storedPath)) {
      final normalizedRelative = p.normalize(storedPath);
      final attachmentsPrefix = 'attachments${Platform.pathSeparator}';
      if (normalizedRelative
          .toLowerCase()
          .startsWith(attachmentsPrefix.toLowerCase())) {
        return p.normalize(
          p.join(attachmentsRoot,
              normalizedRelative.substring(attachmentsPrefix.length)),
        );
      }
      return p.normalize(p.join(attachmentsRoot, normalizedRelative));
    }

    return normalizedStoredPath;
  }

  String _toManagedPath(String absolutePath, String attachmentsRoot) {
    if (!_isInsideDirectory(absolutePath, attachmentsRoot)) {
      return absolutePath;
    }

    final relative =
        p.relative(absolutePath, from: attachmentsRoot).replaceAll('\\', '/');
    return '$_managedPathPrefix$relative';
  }

  bool _isManagedPath(String value) {
    return value.startsWith(_managedPathPrefix);
  }

  String? _extractRelativeFromAttachments(String filePath) {
    final normalizedPath = _normalizePath(filePath);
    final marker =
        '${Platform.pathSeparator}attachments${Platform.pathSeparator}';
    final normalizedComparable = _normalizeForCompare(normalizedPath);
    final markerComparable = _normalizeForCompare(marker);
    final index = normalizedComparable.indexOf(markerComparable);
    if (index < 0) {
      return null;
    }
    return normalizedPath.substring(index + marker.length);
  }

  bool _isInsideDirectory(String filePath, String directoryPath) {
    var normalizedDirectory = _normalizeForCompare(directoryPath);
    final normalizedFilePath = _normalizeForCompare(filePath);
    if (!normalizedDirectory.endsWith(Platform.pathSeparator)) {
      normalizedDirectory += Platform.pathSeparator;
    }
    return normalizedFilePath.startsWith(normalizedDirectory);
  }

  bool _isSamePath(String first, String second) {
    return _normalizeForCompare(first) == _normalizeForCompare(second);
  }

  String _normalizePath(String path) {
    return p.normalize(p.absolute(path));
  }

  String _normalizeForCompare(String path) {
    var normalized = _normalizePath(path);
    if (Platform.isWindows) {
      normalized = normalized.toLowerCase();
    }
    return normalized;
  }

  String _normalizeDocumentType(String documentType) {
    final normalized = documentType.trim().toLowerCase();
    if (normalized == 'warid' || normalized == 'sadir') {
      return normalized;
    }
    return 'general';
  }

  String _sanitizeName(String name) {
    var sanitized = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
    return sanitized.trim();
  }

  String _randomSuffix(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[_random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  String joinPath(String part1, String part2, [String? part3, String? part4]) {
    if (part3 == null) {
      return p.join(part1, part2);
    }
    if (part4 == null) {
      return p.join(part1, part2, part3);
    }
    return p.join(part1, part2, part3, part4);
  }
}
