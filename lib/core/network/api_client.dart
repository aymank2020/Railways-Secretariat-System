import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'api_session.dart';

/// Callback type used to re-authenticate when a 401 is received.
///
/// The [ApiClient] itself does not know about credentials; the caller
/// supplies a function that performs login and returns `true` on success
/// (which also refreshes [ApiSession.accessToken]).
typedef ReAuthenticator = Future<bool> Function();

class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;

  /// Maximum time to wait for a single HTTP request to complete.
  final Duration requestTimeout;

  /// How many times to retry a request on transient errors (network, 5xx).
  final int maxRetries;

  /// Optional callback to re-authenticate when the server returns 401.
  /// If set, a single retry is attempted after successful re-auth.
  ReAuthenticator? onUnauthorized;

  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 15),
    this.maxRetries = 3,
    this.onUnauthorized,
  })  : baseUrl = _normalizeBaseUrl(baseUrl),
        _httpClient = httpClient ?? http.Client();

  static String _normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$normalizedPath');
    if (query == null || query.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: query);
  }

  Map<String, String> _headers({bool withJson = true}) {
    final headers = <String, String>{};
    if (withJson) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }

    final token = ApiSession.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  ApiRequestException _buildException(http.Response response) {
    final decoded = _decodeBody(response);
    if (decoded is Map && decoded['message'] is String) {
      return ApiRequestException(
        statusCode: response.statusCode,
        message: decoded['message'] as String,
      );
    }
    return ApiRequestException(
      statusCode: response.statusCode,
      message: 'Request failed (${response.statusCode}): ${response.body}',
    );
  }

  // ---------------------------------------------------------------------------
  // Retry / timeout / re-auth logic
  // ---------------------------------------------------------------------------

  /// Returns `true` if the error is considered transient and worth retrying.
  bool _isTransient(Object error) {
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;
    // SocketException, HandshakeException, etc. are wrapped in ClientException
    // on some platforms; also check the string for common patterns.
    final msg = error.toString().toLowerCase();
    return msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('network is unreachable') ||
        msg.contains('handshakeexception');
  }

  bool _isTransientStatusCode(int statusCode) {
    return statusCode == 502 || statusCode == 503 || statusCode == 504;
  }

  /// Execute [action] with retry + timeout + 401 re-auth.
  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() action,
  ) async {
    Object? lastError;

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await action().timeout(requestTimeout);

        // Handle 401 Unauthorized — attempt re-authentication once.
        // Skip the re-auth callback when the failing request is itself the
        // login endpoint, otherwise a stale saved password (e.g. after the
        // user changes it on another device) keeps re-running login through
        // `onUnauthorized`, which in turn re-issues the same login call,
        // burning through the server's rate-limiter and bubbling up
        // confusing minified exceptions instead of "invalid credentials".
        final isLoginCall =
            response.request?.url.path.endsWith('/api/auth/login') ?? false;
        if (response.statusCode == 401 && attempt == 0 && !isLoginCall) {
          final reAuth = onUnauthorized;
          if (reAuth != null) {
            final success = await reAuth();
            if (success) {
              // Retry the original request with the refreshed token.
              return await action().timeout(requestTimeout);
            }
          }
        }

        // Retry on transient server errors.
        if (_isTransientStatusCode(response.statusCode) &&
            attempt < maxRetries) {
          lastError = _buildException(response);
          await _backoff(attempt);
          continue;
        }

        return response;
      } catch (e) {
        lastError = e;
        if (!_isTransient(e) || attempt >= maxRetries) {
          rethrow;
        }
        await _backoff(attempt);
      }
    }

    // Should not reach here, but just in case:
    throw lastError ?? StateError('Request failed after $maxRetries retries');
  }

  Future<void> _backoff(int attempt) {
    // Exponential backoff: 500ms, 1s, 2s, … capped at 8s, with jitter.
    final baseMs = 500 * pow(2, attempt).toInt();
    final cappedMs = baseMs.clamp(500, 8000);
    final jitter = Random().nextInt((cappedMs * 0.3).round());
    return Future<void>.delayed(Duration(milliseconds: cappedMs + jitter));
  }

  // ---------------------------------------------------------------------------
  // Public HTTP helpers
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _executeWithRetry(
      () => _httpClient.get(
        _buildUri(path, query),
        headers: _headers(withJson: false),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _buildException(response);
    }

    final decoded = _decodeBody(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _executeWithRetry(
      () => _httpClient.get(
        _buildUri(path, query),
        headers: _headers(withJson: false),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _buildException(response);
    }

    final decoded = _decodeBody(response);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    Object? body,
  }) async {
    final response = await _executeWithRetry(
      () => _httpClient.post(
        _buildUri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _buildException(response);
    }

    final decoded = _decodeBody(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> putMap(
    String path, {
    Object? body,
  }) async {
    final response = await _executeWithRetry(
      () => _httpClient.put(
        _buildUri(path),
        headers: _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _buildException(response);
    }

    final decoded = _decodeBody(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return <String, dynamic>{};
  }

  Future<void> delete(String path) async {
    final response = await _executeWithRetry(
      () => _httpClient.delete(
        _buildUri(path),
        headers: _headers(withJson: false),
      ),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _buildException(response);
    }
  }
}

class ApiRequestException implements Exception {
  final int statusCode;
  final String message;

  const ApiRequestException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => message;
}
