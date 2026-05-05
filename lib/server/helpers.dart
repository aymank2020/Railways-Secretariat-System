import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:railway_secretariat/features/history/data/models/deleted_record_model.dart';
import 'package:railway_secretariat/server/session_store.dart';

/// Exception thrown by API route handlers to signal an error response.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException(this.statusCode, this.message);
}

/// Translate a raw SQLite constraint error into a user-friendly
/// [ApiException] with an Arabic message and an appropriate HTTP status.
///
/// The Dart server uses sqflite, which surfaces SQLite errors as
/// `DatabaseException`s whose `toString()` contains the raw SQLite error
/// text. We match on that text rather than on a typed enum because the
/// constraint kind is the most reliable signal across sqflite versions and
/// across native vs. FFI vs. web backends.
///
/// Returns `null` if [error] does not look like a known constraint
/// violation; the caller should then fall through to its existing
/// 500 / generic handler.
ApiException? mapDatabaseConstraintError(Object error) {
  final raw = error.toString();
  final lowered = raw.toLowerCase();

  // --- Foreign-key violation (e.g. trying to delete a user who authored
  //     warid/sadir records, or referencing a non-existent classification).
  if (lowered.contains('foreign key constraint failed')) {
    return const ApiException(
      HttpStatus.conflict,
      'تعذّر إتمام العملية: يوجد سجلات أخرى مرتبطة بهذا العنصر. '
      'يجب حذف السجلات المرتبطة أو إلغاء ربطها أولاً.',
    );
  }

  // --- Unique-key violation (qaid_number, username, etc.).
  if (lowered.contains('unique constraint failed')) {
    final column = _extractFailingColumn(raw);
    final hint = column != null ? ' (الحقل: $column)' : '';
    return ApiException(
      HttpStatus.conflict,
      'القيمة المُدخلة موجودة مسبقاً ولا يمكن تكرارها$hint.',
    );
  }

  // --- NOT NULL violation: a required column is missing.
  if (lowered.contains('not null constraint failed')) {
    final column = _extractFailingColumn(raw);
    final hint = column != null ? ' ($column)' : '';
    return ApiException(
      HttpStatus.badRequest,
      'حقل مطلوب لم يُملأ$hint.',
    );
  }

  // --- CHECK constraint violation (e.g. role IN ('admin','user')).
  if (lowered.contains('check constraint failed')) {
    return const ApiException(
      HttpStatus.badRequest,
      'إحدى القيم المُدخلة غير مسموح بها وفقاً لقيود قاعدة البيانات.',
    );
  }

  return null;
}

/// Extract the failing column name from a SQLite constraint error message
/// of the form `... constraint failed: table.column`. Returns `null` when
/// the format does not match.
String? _extractFailingColumn(String raw) {
  final match = RegExp(r'constraint failed:\s*([^\s]+)').firstMatch(raw);
  return match?.group(1);
}

/// Maximum allowed request body size (25 MB).
///
/// Attachments are uploaded as base64-encoded JSON strings, which inflate the
/// raw bytes by ~33%. A 25 MB body therefore fits an ~18 MB binary payload —
/// large enough for the project's use cases (PDFs, scanned images, Excel
/// imports) but small enough that a few concurrent uploads cannot exhaust
/// the container's 1 GB memory cap (see docker-compose.prod.yml). nginx in
/// front of the API enforces a parallel `client_max_body_size 30m` limit.
const int maxRequestBodyBytes = 25 * 1024 * 1024;

/// Read and parse the JSON body of an HTTP request.
///
/// Rejects payloads larger than [maxRequestBodyBytes] to prevent
/// memory exhaustion from oversized uploads.
Future<Map<String, dynamic>> readJsonBody(HttpRequest request) async {
  final chunks = <List<int>>[];
  var totalBytes = 0;
  await for (final chunk in request) {
    totalBytes += chunk.length;
    if (totalBytes > maxRequestBodyBytes) {
      throw const ApiException(
        HttpStatus.requestEntityTooLarge,
        'Request body exceeds the maximum allowed size.',
      );
    }
    chunks.add(chunk);
  }
  final content = utf8.decode(chunks.expand((c) => c).toList());
  if (content.trim().isEmpty) {
    return <String, dynamic>{};
  }
  final decoded = jsonDecode(content);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const ApiException(HttpStatus.badRequest, 'Invalid JSON payload.');
}

/// Ensure a dynamic value is a Map, throwing if not.
Map<String, dynamic> ensureMap(dynamic value, {required String fieldName}) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  throw ApiException(
    HttpStatus.badRequest,
    'Field "$fieldName" must be an object.',
  );
}

/// Write a JSON response.
void writeJson(HttpResponse response, Object payload) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(payload));
}

/// Parse a date string, returning null if empty or invalid.
DateTime? parseDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim());
}

/// Parse an integer string, returning null if empty or invalid.
int? parseInt(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return int.tryParse(raw.trim());
}

/// Parse a boolean from various formats.
bool parseBool(dynamic raw) {
  if (raw is bool) return raw;
  final normalized = raw?.toString().trim().toLowerCase() ?? '';
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

/// Decode base64-encoded bytes, throwing on failure.
Uint8List decodeBase64(String base64Value) {
  if (base64Value.trim().isEmpty) {
    throw const ApiException(
      HttpStatus.badRequest,
      'fileBytesBase64 is required.',
    );
  }
  try {
    return base64Decode(base64Value);
  } catch (_) {
    throw const ApiException(
      HttpStatus.badRequest,
      'fileBytesBase64 is invalid.',
    );
  }
}

/// Convert a DeletedRecordModel to a JSON-compatible map.
Map<String, dynamic> deletedRecordToMap(DeletedRecordModel item) {
  return <String, dynamic>{
    'id': item.id,
    'document_type': item.documentType,
    'original_record_id': item.originalRecordId,
    'archived_payload': jsonEncode(item.archivedPayload),
    'deleted_at': item.deletedAt.toIso8601String(),
    'deleted_by': item.deletedBy,
    'deleted_by_name': item.deletedByName,
    'is_restored': item.isRestored ? 1 : 0,
    'restored_at': item.restoredAt?.toIso8601String(),
    'restored_by': item.restoredBy,
    'restored_by_name': item.restoredByName,
    'restored_record_id': item.restoredRecordId,
  };
}

/// Convert an import outcome to a JSON-compatible map.
Map<String, dynamic> importOutcomeToMap(dynamic outcome) {
  final errors = (outcome.errors as List)
      .map(
        (item) => <String, dynamic>{
          'rowNumber': item.rowNumber,
          'message': item.message,
        },
      )
      .toList(growable: false);

  return <String, dynamic>{
    'totalRows': outcome.totalRows,
    'importedRows': outcome.importedRows,
    'failedRows': outcome.failedRows,
    'errors': errors,
  };
}

// ---------------------------------------------------------------------------
// Permission checks
// ---------------------------------------------------------------------------

void requireUsersPermission(ServerSession session) {
  if (session.isAdmin || session.canManageUsers) return;
  throw const ApiException(
    HttpStatus.forbidden,
    'You do not have permission to manage users.',
  );
}

void requireWaridPermission(ServerSession session) {
  if (session.isAdmin || session.canManageWarid) return;
  throw const ApiException(
    HttpStatus.forbidden,
    'You do not have permission to manage warid records.',
  );
}

void requireSadirPermission(ServerSession session) {
  if (session.isAdmin || session.canManageSadir) return;
  throw const ApiException(
    HttpStatus.forbidden,
    'You do not have permission to manage sadir records.',
  );
}

void requireImportPermission(ServerSession session) {
  if (session.isAdmin || session.canImportExcel) return;
  throw const ApiException(
    HttpStatus.forbidden,
    'You do not have permission to import/export OCR templates.',
  );
}

void requireDocumentAccessPermission(ServerSession session) {
  if (session.isAdmin || session.canManageWarid || session.canManageSadir) {
    return;
  }
  throw const ApiException(
    HttpStatus.forbidden,
    'You do not have permission to access attachments.',
  );
}

void requireDocumentTypePermission(ServerSession session, String documentType) {
  final normalized = documentType.trim().toLowerCase();
  if (normalized.isEmpty) {
    throw const ApiException(
      HttpStatus.badRequest,
      'documentType is required.',
    );
  }
  if (normalized == 'warid') {
    requireWaridPermission(session);
    return;
  }
  if (normalized == 'sadir') {
    requireSadirPermission(session);
    return;
  }
  throw ApiException(
    HttpStatus.badRequest,
    'Unsupported document type: $documentType',
  );
}

/// Extract and validate the Bearer token from the request, returning the session.
ServerSession requireSession(HttpRequest request, SessionStore sessionStore) {
  final authHeader =
      request.headers.value(HttpHeaders.authorizationHeader) ?? '';
  final token = authHeader.startsWith('Bearer ')
      ? authHeader.substring('Bearer '.length).trim()
      : '';
  if (token.isEmpty) {
    throw const ApiException(HttpStatus.unauthorized, 'Missing bearer token.');
  }

  final session = sessionStore.find(token);
  if (session == null) {
    throw const ApiException(
      HttpStatus.unauthorized,
      'Invalid or expired token.',
    );
  }
  return session;
}

/// Extract the raw Bearer token string from request headers.
String extractToken(HttpRequest request) {
  final authHeader =
      request.headers.value(HttpHeaders.authorizationHeader) ?? '';
  return authHeader.startsWith('Bearer ')
      ? authHeader.substring('Bearer '.length).trim()
      : '';
}

/// Get the client IP address from the request.
///
/// Trust order:
///   1. `X-Real-IP` — set by our nginx (`proxy_set_header X-Real-IP $remote_addr`)
///      from the actual TCP peer; the client cannot influence it because nginx
///      always overwrites the header before forwarding.
///   2. The **last** entry of `X-Forwarded-For` — nginx uses
///      `$proxy_add_x_forwarded_for` which *appends* the real client IP to
///      whatever the client sent, so the last comma-separated entry is the
///      one nginx added and is therefore trustworthy. Reading the **first**
///      entry would let any attacker spoof their IP by sending
///      `X-Forwarded-For: 1.2.3.4` and bypass the login rate-limiter.
///   3. The TCP peer's address — used when the server is reached directly
///      (e.g. local development without nginx in front).
String getClientIp(HttpRequest request) {
  final realIp = request.headers.value('X-Real-IP');
  if (realIp != null && realIp.trim().isNotEmpty) {
    return realIp.trim();
  }
  final forwarded = request.headers.value('X-Forwarded-For');
  if (forwarded != null && forwarded.trim().isNotEmpty) {
    final parts = forwarded.split(',');
    return parts.last.trim();
  }
  return request.connectionInfo?.remoteAddress.address ?? 'unknown';
}
