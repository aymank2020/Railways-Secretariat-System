import 'dart:convert';
import 'dart:math';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Represents an authenticated server session.
class ServerSession {
  final int userId;
  final String username;
  final String role;
  final bool canManageUsers;
  final bool canManageWarid;
  final bool canManageSadir;
  final bool canImportExcel;
  final DateTime expiresAt;

  const ServerSession({
    required this.userId,
    required this.username,
    required this.role,
    required this.canManageUsers,
    required this.canManageWarid,
    required this.canManageSadir,
    required this.canImportExcel,
    required this.expiresAt,
  });

  bool get isAdmin => role.trim().toLowerCase() == 'admin';
  bool get isExpired => expiresAt.isBefore(DateTime.now());
}

/// Manages server sessions with SQLite persistence.
///
/// Sessions survive server restarts. Expired sessions are cleaned up
/// periodically.
class SessionStore {
  static const Duration defaultSessionTtl = Duration(hours: 8);
  static const Duration _cleanupInterval = Duration(minutes: 30);

  final Duration sessionTtl;
  final Random _random = Random.secure();

  // In-memory cache for fast lookups, backed by SQLite.
  final Map<String, ServerSession> _cache = <String, ServerSession>{};
  Database? _db;
  DateTime _lastCleanup = DateTime.now();

  SessionStore({this.sessionTtl = defaultSessionTtl});

  /// Initialize the SQLite-backed session store.
  Future<void> initialize(Database db) async {
    _db = db;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS server_sessions (
        token TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        username TEXT NOT NULL,
        role TEXT NOT NULL,
        can_manage_users INTEGER NOT NULL DEFAULT 0,
        can_manage_warid INTEGER NOT NULL DEFAULT 1,
        can_manage_sadir INTEGER NOT NULL DEFAULT 1,
        can_import_excel INTEGER NOT NULL DEFAULT 0,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Load existing valid sessions into cache.
    await _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    final db = _db;
    if (db == null) return;

    final now = DateTime.now().toIso8601String();
    final rows = await db.query(
      'server_sessions',
      where: 'expires_at > ?',
      whereArgs: [now],
    );

    for (final row in rows) {
      final token = row['token'] as String;
      _cache[token] = ServerSession(
        userId: row['user_id'] as int,
        username: row['username'] as String,
        role: row['role'] as String,
        canManageUsers: (row['can_manage_users'] as int) == 1,
        canManageWarid: (row['can_manage_warid'] as int) == 1,
        canManageSadir: (row['can_manage_sadir'] as int) == 1,
        canImportExcel: (row['can_import_excel'] as int) == 1,
        expiresAt: DateTime.parse(row['expires_at'] as String),
      );
    }
  }

  /// Create a new session and return the token.
  Future<String> createSession({
    required int userId,
    required String username,
    required String role,
    required bool canManageUsers,
    required bool canManageWarid,
    required bool canManageSadir,
    required bool canImportExcel,
  }) async {
    await _maybeCleanup();

    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    final expiresAt = DateTime.now().add(sessionTtl);

    final session = ServerSession(
      userId: userId,
      username: username,
      role: role,
      canManageUsers: canManageUsers,
      canManageWarid: canManageWarid,
      canManageSadir: canManageSadir,
      canImportExcel: canImportExcel,
      expiresAt: expiresAt,
    );

    _cache[token] = session;

    // Persist to SQLite.
    final db = _db;
    if (db != null) {
      await db.insert('server_sessions', {
        'token': token,
        'user_id': userId,
        'username': username,
        'role': role,
        'can_manage_users': canManageUsers ? 1 : 0,
        'can_manage_warid': canManageWarid ? 1 : 0,
        'can_manage_sadir': canManageSadir ? 1 : 0,
        'can_import_excel': canImportExcel ? 1 : 0,
        'expires_at': expiresAt.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return token;
  }

  /// Find a valid (non-expired) session by token.
  ServerSession? find(String token) {
    final session = _cache[token];
    if (session == null) return null;
    if (session.isExpired) {
      _cache.remove(token);
      _removeFromDb(token);
      return null;
    }
    return session;
  }

  /// Refresh (extend) an existing session. Returns a new token.
  Future<String?> refreshSession(String oldToken) async {
    final session = find(oldToken);
    if (session == null) return null;

    // Remove old session.
    _cache.remove(oldToken);
    await _removeFromDb(oldToken);

    // Create new session with extended TTL.
    return createSession(
      userId: session.userId,
      username: session.username,
      role: session.role,
      canManageUsers: session.canManageUsers,
      canManageWarid: session.canManageWarid,
      canManageSadir: session.canManageSadir,
      canImportExcel: session.canImportExcel,
    );
  }

  /// Remove a session (logout).
  Future<void> removeSession(String token) async {
    _cache.remove(token);
    await _removeFromDb(token);
  }

  /// Revoke every session that belongs to [userId], optionally keeping a
  /// single live token (e.g. the one the caller is currently using to
  /// rotate their own password). Used after a password change so that any
  /// other device that had a live token must re-authenticate.
  Future<int> removeAllSessionsForUser(
    int userId, {
    String? exceptToken,
  }) async {
    final removedTokens = <String>[];
    _cache.removeWhere((token, session) {
      if (session.userId != userId) return false;
      if (exceptToken != null && token == exceptToken) return false;
      removedTokens.add(token);
      return true;
    });

    final db = _db;
    if (db != null) {
      if (exceptToken != null) {
        await db.delete(
          'server_sessions',
          where: 'user_id = ? AND token != ?',
          whereArgs: [userId, exceptToken],
        );
      } else {
        await db.delete(
          'server_sessions',
          where: 'user_id = ?',
          whereArgs: [userId],
        );
      }
    }
    return removedTokens.length;
  }

  Future<void> _removeFromDb(String token) async {
    final db = _db;
    if (db == null) return;
    await db.delete('server_sessions', where: 'token = ?', whereArgs: [token]);
  }

  Future<void> _maybeCleanup() async {
    final now = DateTime.now();
    if (now.difference(_lastCleanup) < _cleanupInterval) return;
    _lastCleanup = now;

    // Remove expired from cache.
    final expiredKeys = _cache.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList(growable: false);
    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    // Remove expired from DB.
    final db = _db;
    if (db != null) {
      await db.delete(
        'server_sessions',
        where: 'expires_at < ?',
        whereArgs: [now.toIso8601String()],
      );
    }
  }
}
