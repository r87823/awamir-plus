import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionStore {
  const AuthSessionStore();

  static const _mockUsernameKey = 'awamir_mock_username';

  Future<void> saveMockUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mockUsernameKey, username);
  }

  Future<String?> readMockUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mockUsernameKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_mockUsernameKey);
  }
}
