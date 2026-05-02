/// Shims for `package:shared_preferences/shared_preferences.dart` without Flutter.
/// On the server, storage paths come from environment variables, not SharedPreferences.

class SharedPreferences {
  static final SharedPreferences _instance = SharedPreferences._();
  final Map<String, String> _data = {};

  SharedPreferences._();

  static Future<SharedPreferences> getInstance() async => _instance;

  String? getString(String key) => _data[key];

  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  bool containsKey(String key) => _data.containsKey(key);
}
