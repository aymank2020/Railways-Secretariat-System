import 'package:http/http.dart' as http;
import 'package:railway_secretariat/core/platform/shared_preferences_shims.dart'
    if (dart.library.ui) 'package:shared_preferences/shared_preferences.dart';

/// Manages the persisted server URL and provides helpers to test
/// connectivity against the configured API endpoint.
class ServerSettingsService {
  static const String _serverUrlKey = 'secretariat_server_url';
  static const Duration _healthTimeout = Duration(seconds: 5);

  static final ServerSettingsService _instance =
      ServerSettingsService._internal();

  String? _cachedUrl;

  factory ServerSettingsService() => _instance;

  ServerSettingsService._internal();

  /// Returns the saved server URL, or `null` if none was persisted.
  Future<String?> getSavedServerUrl() async {
    if (_cachedUrl != null && _cachedUrl!.trim().isNotEmpty) {
      return _cachedUrl;
    }

    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_serverUrlKey)?.trim();
    if (url != null && url.isNotEmpty) {
      _cachedUrl = _normalizeUrl(url);
      return _cachedUrl;
    }
    return null;
  }

  /// Persists [url] as the server address. Pass `null` or empty to clear.
  Future<void> saveServerUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _normalizeUrl(url);
    if (normalized == null || normalized.isEmpty) {
      await prefs.remove(_serverUrlKey);
      _cachedUrl = null;
    } else {
      await prefs.setString(_serverUrlKey, normalized);
      _cachedUrl = normalized;
    }
  }

  /// Clears the saved server URL (switch back to local mode).
  Future<void> clearServerUrl() async {
    await saveServerUrl(null);
  }

  /// Tests whether the API at [url] is reachable by calling `/api/health`.
  /// Returns a [ServerHealthResult] with the outcome.
  Future<ServerHealthResult> testConnection(String url) async {
    final normalized = _normalizeUrl(url);
    if (normalized == null || normalized.isEmpty) {
      return const ServerHealthResult(
        success: false,
        message: 'عنوان السيرفر غير صالح',
      );
    }

    try {
      final uri = Uri.parse('$normalized/api/health');
      final response = await http.get(uri).timeout(_healthTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ServerHealthResult(
          success: true,
          message: 'السيرفر متصل ويعمل بنجاح ✅',
          statusCode: response.statusCode,
        );
      }

      return ServerHealthResult(
        success: false,
        message: 'السيرفر رد برمز خطأ: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on Exception catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('TimeoutException')) {
        return const ServerHealthResult(
          success: false,
          message: 'انتهت مهلة الاتصال — تأكد من عنوان السيرفر والشبكة',
        );
      }
      if (errorMsg.contains('SocketException') ||
          errorMsg.contains('Connection refused')) {
        return const ServerHealthResult(
          success: false,
          message: 'تعذر الاتصال — تأكد أن السيرفر يعمل والشبكة متصلة',
        );
      }
      return ServerHealthResult(
        success: false,
        message: 'خطأ في الاتصال: $errorMsg',
      );
    }
  }

  /// Normalize: trim, remove trailing slash.
  String? _normalizeUrl(String? raw) {
    var value = raw?.trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    return value;
  }

  void clearCache() {
    _cachedUrl = null;
  }
}

/// The result of a health-check call against the API server.
class ServerHealthResult {
  final bool success;
  final String message;
  final int? statusCode;

  const ServerHealthResult({
    required this.success,
    required this.message,
    this.statusCode,
  });
}
