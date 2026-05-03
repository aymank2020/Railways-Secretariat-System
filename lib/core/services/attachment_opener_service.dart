import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import 'package:railway_secretariat/core/network/api_client.dart';
import 'package:railway_secretariat/core/services/server_settings_service.dart';
import 'package:railway_secretariat/features/documents/data/datasources/attachment_storage_service.dart';

import '../platform/web_download_stub.dart'
    if (dart.library.html) '../platform/web_download_html.dart';

/// Outcome of an attempt to open or download an attachment.
class AttachmentOpenResult {
  final bool ok;
  final String? errorMessage;

  const AttachmentOpenResult._(this.ok, this.errorMessage);

  static const AttachmentOpenResult success = AttachmentOpenResult._(true, null);

  factory AttachmentOpenResult.failure(String message) =>
      AttachmentOpenResult._(false, message);
}

/// Cross-platform helper that hides the difference between
///
///   * native (Windows / Android / iOS / macOS / Linux): resolve the stored
///     path to a local file and ask the OS to open it via `OpenFilex`, and
///   * web: download the bytes from the server and trigger a browser
///     download via an `<a download>` element so the user gets a real file.
///
/// Call sites used to early-return with a "not supported" snackbar on web;
/// they should now `await AttachmentOpenerService().open(...)` and surface
/// `errorMessage` on failure.
class AttachmentOpenerService {
  AttachmentOpenerService({AttachmentStorageService? storage})
      : _storage = storage ?? AttachmentStorageService();

  final AttachmentStorageService _storage;
  ApiClient? _cachedApiClient;
  String? _cachedBaseUrl;

  Future<AttachmentOpenResult> open({
    required String? storedPath,
    String? originalFileName,
  }) async {
    final trimmedStoredPath = storedPath?.trim() ?? '';
    if (trimmedStoredPath.isEmpty) {
      return AttachmentOpenResult.failure('لا يوجد ملف مرفق لهذا السجل');
    }

    if (kIsWeb) {
      return _openOnWeb(
        storedPath: trimmedStoredPath,
        fallbackFileName: originalFileName,
      );
    }

    return _openOnNative(storedPath: trimmedStoredPath);
  }

  Future<AttachmentOpenResult> _openOnNative({
    required String storedPath,
  }) async {
    final localPath = await _storage.resolveAttachmentPath(storedPath);
    if (localPath == null || localPath.trim().isEmpty) {
      return AttachmentOpenResult.failure('لا يمكن تحديد مكان الملف على الجهاز');
    }
    final result = await OpenFilex.open(localPath);
    if (result.type == ResultType.done) {
      return AttachmentOpenResult.success;
    }
    return AttachmentOpenResult.failure('تعذر فتح الملف: ${result.message}');
  }

  Future<AttachmentOpenResult> _openOnWeb({
    required String storedPath,
    String? fallbackFileName,
  }) async {
    final apiClient = await _resolveApiClient();
    if (apiClient == null) {
      return AttachmentOpenResult.failure(
        'تعذر الاتصال بالخادم لتنزيل الملف.',
      );
    }

    Map<String, dynamic> response;
    try {
      response = await apiClient.postMap(
        '/api/attachments/download',
        body: <String, dynamic>{'filePath': storedPath},
      );
    } catch (e) {
      return AttachmentOpenResult.failure('فشل تنزيل الملف من الخادم: $e');
    }

    final rawBase64 = (response['fileBytesBase64'] ?? '').toString();
    if (rawBase64.trim().isEmpty) {
      return AttachmentOpenResult.failure('الملف غير موجود على الخادم.');
    }

    Uint8List bytes;
    try {
      bytes = base64Decode(rawBase64);
    } catch (_) {
      return AttachmentOpenResult.failure('استلمنا ردًا غير صالح من الخادم.');
    }

    if (bytes.isEmpty) {
      return AttachmentOpenResult.failure('الملف فارغ.');
    }

    final serverFileName = (response['fileName'] ?? '').toString().trim();
    final fileName = serverFileName.isNotEmpty
        ? serverFileName
        : (fallbackFileName?.trim().isNotEmpty == true
            ? fallbackFileName!.trim()
            : _fileNameFromStoredPath(storedPath));

    triggerBrowserDownload(
      bytes: bytes,
      fileName: fileName,
      mimeType: _guessMimeType(fileName),
    );
    return AttachmentOpenResult.success;
  }

  Future<ApiClient?> _resolveApiClient() async {
    final baseUrl = await _resolveBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      return null;
    }
    if (_cachedApiClient != null && _cachedBaseUrl == baseUrl) {
      return _cachedApiClient;
    }
    _cachedBaseUrl = baseUrl;
    _cachedApiClient = ApiClient(baseUrl: baseUrl);
    return _cachedApiClient;
  }

  Future<String?> _resolveBaseUrl() async {
    const fromDefine = String.fromEnvironment('API_BASE_URL');
    final trimmedDefine = fromDefine.trim();
    if (trimmedDefine.isNotEmpty) {
      return trimmedDefine;
    }
    if (kIsWeb) {
      // On web the Flutter bundle is served by the same nginx that
      // reverse-proxies /api/*, so Uri.base.origin is the right base URL.
      return Uri.base.origin;
    }
    return ServerSettingsService().getSavedServerUrl();
  }

  String _fileNameFromStoredPath(String storedPath) {
    final name = p.basename(storedPath);
    return name.isEmpty ? 'attachment.bin' : name;
  }

  String _guessMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.svg':
        return 'image/svg+xml';
      case '.txt':
      case '.log':
        return 'text/plain; charset=utf-8';
      case '.csv':
        return 'text/csv; charset=utf-8';
      case '.json':
        return 'application/json; charset=utf-8';
      case '.xml':
        return 'application/xml; charset=utf-8';
      case '.zip':
        return 'application/zip';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }
}
