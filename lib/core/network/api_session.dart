class ApiSession {
  static String? _accessToken;

  static String? get accessToken => _accessToken;

  static bool get hasToken =>
      _accessToken != null && _accessToken!.trim().isNotEmpty;

  static void setToken(String? token) {
    final normalized = token?.trim();
    _accessToken = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
  }

  static void clear() {
    _accessToken = null;
  }
}
