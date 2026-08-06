import 'package:shared_preferences/shared_preferences.dart';

/// This app runs on a separate physical device from the POS register (a
/// second screen facing the customer), so — unlike the POS app's
/// `AppConfig.baseUrl` — there is no sensible hardcoded default such as
/// `localhost`. The server URL is whatever the staff types into
/// `ConnectScreen` once, persisted here so it survives app restarts.
class AppConfig {
  static const String _serverUrlKey = 'customer_display_server_url';
  static const String _sessionCodeKey = 'customer_display_session_code';

  static Future<String?> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  static Future<void> saveServerUrl(String serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, serverUrl);
  }

  static Future<String?> loadSessionCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionCodeKey);
  }

  static Future<void> saveSessionCode(String sessionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionCodeKey, sessionCode);
  }
}
