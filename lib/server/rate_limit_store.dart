import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// SQLite-backed log of rate-limit attempts.
///
/// Stores `(ip, attempted_at)` rows so the in-memory [RateLimiter] in
/// `middleware.dart` can survive a server restart. Without this, an
/// attacker could simply wait for the next deploy / SIGHUP / OOM-kill
/// to reset their attempt counter to zero (§4.6 of the code review).
///
/// Public API is intentionally narrow: load the recent window into
/// memory at boot, append new attempts, prune old ones. Callers are
/// expected to do the actual `allow / deny` arithmetic in memory for
/// latency reasons — the store is just a durable mirror.
class RateLimitStore {
  static const String _table = 'rate_limit_attempts';

  final Database _db;

  RateLimitStore._(this._db);

  /// Open the store on [db], creating the table and indexes if they
  /// don't yet exist. Returns a ready-to-use instance.
  static Future<RateLimitStore> open(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table (
        ip TEXT NOT NULL,
        attempted_at INTEGER NOT NULL
      )
    ''');
    // Composite index for the per-IP `WHERE ip = ? AND attempted_at > ?`
    // query that runs on every login attempt.
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_${_table}_ip_time
      ON $_table (ip, attempted_at)
    ''');
    // Standalone index used by [purgeBefore] to delete a rolling
    // window's worth of expired rows in one shot.
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_${_table}_time
      ON $_table (attempted_at)
    ''');
    return RateLimitStore._(db);
  }

  /// Append one attempt for [ip] at [at].
  Future<void> recordAttempt(String ip, DateTime at) async {
    await _db.insert(_table, {
      'ip': ip,
      'attempted_at': at.millisecondsSinceEpoch,
    });
  }

  /// Return every attempt newer than [since], grouped by IP. Used at
  /// startup to seed the in-memory tracker so a restart doesn't reset
  /// counters.
  Future<Map<String, List<DateTime>>> loadAttemptsSince(DateTime since) async {
    final rows = await _db.query(
      _table,
      columns: ['ip', 'attempted_at'],
      where: 'attempted_at >= ?',
      whereArgs: [since.millisecondsSinceEpoch],
    );
    final map = <String, List<DateTime>>{};
    for (final row in rows) {
      final ip = (row['ip'] ?? '').toString();
      if (ip.isEmpty) continue;
      final ms = (row['attempted_at'] is int)
          ? row['attempted_at'] as int
          : int.tryParse((row['attempted_at'] ?? '0').toString()) ?? 0;
      map
          .putIfAbsent(ip, () => <DateTime>[])
          .add(DateTime.fromMillisecondsSinceEpoch(ms));
    }
    for (final list in map.values) {
      list.sort();
    }
    return map;
  }

  /// Delete every attempt strictly older than [cutoff]. Safe to call
  /// frequently — runs against a covering index.
  Future<int> purgeBefore(DateTime cutoff) async {
    return _db.delete(
      _table,
      where: 'attempted_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }
}
