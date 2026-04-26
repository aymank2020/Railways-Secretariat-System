import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:railway_secretariat/core/services/server_settings_service.dart';

/// Possible connection states for the remote API server.
///
/// Named [ServerConnectionState] to avoid collision with Flutter's
/// built-in [ConnectionState] from `dart:async`.
enum ServerConnectionState {
  /// Initial state — haven't checked yet.
  unknown,

  /// Successfully reached the health endpoint.
  connected,

  /// Failed to reach the health endpoint.
  disconnected,

  /// Currently pinging.
  checking,

  /// Running in local-only mode (no server configured).
  local,
}

/// Provides centralised, app-wide connection status tracking.
///
/// Instead of each widget independently pinging the server, this
/// provider maintains a single timer and notifies all listeners
/// when the connection state changes.
class ConnectionStatusProvider extends ChangeNotifier {
  ServerConnectionState _state = ServerConnectionState.unknown;
  Timer? _timer;
  String? _serverUrl;
  DateTime? _lastChecked;

  /// How often to ping automatically.
  final Duration pingInterval;

  /// Timeout for each health-check request.
  final Duration pingTimeout;

  ConnectionStatusProvider({
    String? serverUrl,
    this.pingInterval = const Duration(seconds: 30),
    this.pingTimeout = const Duration(seconds: 5),
  }) : _serverUrl = serverUrl {
    _init();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  ServerConnectionState get state => _state;

  bool get isConnected => _state == ServerConnectionState.connected;
  bool get isDisconnected => _state == ServerConnectionState.disconnected;
  bool get isLocal => _state == ServerConnectionState.local;
  bool get isChecking => _state == ServerConnectionState.checking;

  /// The last time a check was performed (regardless of outcome).
  DateTime? get lastChecked => _lastChecked;

  /// The server URL currently being monitored.
  String? get serverUrl => _serverUrl;

  /// Manually trigger a connectivity check right now.
  Future<void> checkNow() => _ping();

  /// Update the server URL (e.g. when settings change). Resets state
  /// and starts pinging the new URL.
  void updateServerUrl(String? url) {
    _serverUrl = url;
    _timer?.cancel();
    _timer = null;
    _init();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    // If no URL was provided at construction, try to resolve from settings.
    _serverUrl ??= await ServerSettingsService().getSavedServerUrl();

    if (_serverUrl == null || _serverUrl!.trim().isEmpty) {
      _setState(ServerConnectionState.local);
      return;
    }

    await _ping();
    _timer?.cancel();
    _timer = Timer.periodic(pingInterval, (_) => _ping());
  }

  Future<void> _ping() async {
    final url = _serverUrl;
    if (url == null || url.trim().isEmpty) return;

    _setState(ServerConnectionState.checking);

    try {
      final response = await http
          .get(Uri.parse('$url/api/health'))
          .timeout(pingTimeout);

      _lastChecked = DateTime.now();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _setState(ServerConnectionState.connected);
      } else {
        _setState(ServerConnectionState.disconnected);
      }
    } catch (_) {
      _lastChecked = DateTime.now();
      _setState(ServerConnectionState.disconnected);
    }
  }

  void _setState(ServerConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
