import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionCookieStore {
  const SessionCookieStore({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) : _secureStorage = secureStorage;

  static const _cookieHeaderKey = 'awamir_frappe_cookie_header';

  final FlutterSecureStorage _secureStorage;

  Future<String?> readCookieHeader() {
    return _secureStorage.read(key: _cookieHeaderKey);
  }

  Future<void> saveCookieHeader(String cookieHeader) {
    return _secureStorage.write(key: _cookieHeaderKey, value: cookieHeader);
  }

  Future<void> clear() {
    return _secureStorage.delete(key: _cookieHeaderKey);
  }
}
