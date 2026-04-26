import 'dart:io';

/// CORS middleware - sets appropriate headers on every response.
///
/// When [allowedOrigins] is null or empty, defaults to `*`.
void setCorsHeaders(
  HttpResponse response, {
  List<String>? allowedOrigins,
}) {
  final origin = (allowedOrigins != null && allowedOrigins.isNotEmpty)
      ? allowedOrigins.join(', ')
      : '*';
  response.headers.set('Access-Control-Allow-Origin', origin);
  response.headers.set(
    'Access-Control-Allow-Headers',
    'Origin, X-Requested-With, Content-Type, Accept, Authorization',
  );
  response.headers
      .set('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
}

/// Simple request logger.
///
/// Call [logRequest] at the start of handling and [logResponse] when done.
class RequestLogger {
  final bool enabled;

  const RequestLogger({this.enabled = true});

  void logRequest(HttpRequest request) {
    if (!enabled) return;
    final now = DateTime.now().toIso8601String();
    stdout.writeln(
      '[$now] ${request.method} ${request.uri.path}'
      '${request.uri.query.isNotEmpty ? "?${request.uri.query}" : ""}',
    );
  }

  void logResponse(HttpRequest request, int statusCode, Stopwatch timer) {
    if (!enabled) return;
    final ms = timer.elapsedMilliseconds;
    stdout.writeln(
      '  -> $statusCode (${ms}ms)',
    );
  }
}

/// IP-based rate limiter for specific endpoints (e.g., login).
///
/// Tracks request counts per IP within a sliding window.
class RateLimiter {
  final int maxAttempts;
  final Duration window;

  // Map of IP -> list of timestamps.
  final Map<String, List<DateTime>> _attempts = {};
  DateTime _lastCleanup = DateTime.now();

  RateLimiter({
    this.maxAttempts = 10,
    this.window = const Duration(minutes: 5),
  });

  /// Returns `true` if the request should be allowed, `false` if rate-limited.
  bool allowRequest(String ip) {
    _maybeCleanup();

    final now = DateTime.now();
    final cutoff = now.subtract(window);

    final attempts = _attempts.putIfAbsent(ip, () => <DateTime>[]);
    attempts.removeWhere((t) => t.isBefore(cutoff));
    attempts.add(now);

    return attempts.length <= maxAttempts;
  }

  /// Returns the number of seconds until the rate limit resets for [ip].
  int retryAfterSeconds(String ip) {
    final attempts = _attempts[ip];
    if (attempts == null || attempts.isEmpty) return 0;

    final oldest = attempts.first;
    final resetAt = oldest.add(window);
    final remaining = resetAt.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  void _maybeCleanup() {
    final now = DateTime.now();
    if (now.difference(_lastCleanup).inMinutes < 10) return;
    _lastCleanup = now;

    final cutoff = now.subtract(window);
    final emptyKeys = <String>[];
    for (final entry in _attempts.entries) {
      entry.value.removeWhere((t) => t.isBefore(cutoff));
      if (entry.value.isEmpty) {
        emptyKeys.add(entry.key);
      }
    }
    for (final key in emptyKeys) {
      _attempts.remove(key);
    }
  }
}
