import 'dart:io';
import 'dart:math';

/// CORS middleware - sets appropriate headers on every response.
///
/// When [allowedOrigins] is null or empty, no `Access-Control-Allow-Origin`
/// header is emitted, which means browsers will block cross-origin requests.
/// This is the secure default; the production deployment serves both the
/// Flutter Web bundle and the API from the same origin (via nginx) so CORS
/// headers are not needed there.
///
/// To explicitly allow `*`, set the env var `SECRETARIAT_CORS_ORIGINS=*`.
void setCorsHeaders(
  HttpResponse response, {
  List<String>? allowedOrigins,
}) {
  if (allowedOrigins != null && allowedOrigins.isNotEmpty) {
    final origin = allowedOrigins.length == 1
        ? allowedOrigins.single
        : allowedOrigins.join(', ');
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set('Vary', 'Origin');
  }
  // Always advertise the request-method/header allow-list — these are
  // ignored by browsers when no Allow-Origin header is set.
  response.headers.set(
    'Access-Control-Allow-Headers',
    'Origin, X-Requested-With, Content-Type, Accept, Authorization',
  );
  response.headers
      .set('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  // Expose the request-id header so cross-origin JS can read it from
  // failed responses and surface it in error messages / bug reports.
  response.headers.set('Access-Control-Expose-Headers', 'X-Request-Id');
}

/// Per-request opaque identifier surfaced both in the access log and to the
/// client via the `X-Request-Id` response header. Letting the client see it
/// makes it trivial for an operator to grep for the matching log line when
/// a user reports an error.
///
/// Format: 12 lowercase alphanumerics, e.g. `req-r3k9pa1tlqxy`. Short
/// enough to copy/paste, long enough that collisions within a 10-minute
/// log window are negligible (~62^12 = 3e21 possibilities).
String generateRequestId() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  final buf = StringBuffer('req-');
  for (var i = 0; i < 12; i++) {
    buf.write(alphabet[rng.nextInt(alphabet.length)]);
  }
  return buf.toString();
}

/// Simple request logger.
///
/// Call [logRequest] at the start of handling and [logResponse] when done.
/// Both lines are tagged with the same [requestId], which is also written
/// to the response's `X-Request-Id` header so an operator can correlate
/// what the user saw with what hit the server.
class RequestLogger {
  final bool enabled;

  const RequestLogger({this.enabled = true});

  void logRequest(HttpRequest request, String requestId) {
    if (!enabled) return;
    final now = DateTime.now().toIso8601String();
    stdout.writeln(
      '[$now] [$requestId] ${request.method} ${request.uri.path}'
      '${request.uri.query.isNotEmpty ? "?${request.uri.query}" : ""}',
    );
  }

  void logResponse(
    HttpRequest request,
    String requestId,
    int statusCode,
    Stopwatch timer,
  ) {
    if (!enabled) return;
    final ms = timer.elapsedMilliseconds;
    stdout.writeln(
      '  [$requestId] -> $statusCode (${ms}ms)',
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
