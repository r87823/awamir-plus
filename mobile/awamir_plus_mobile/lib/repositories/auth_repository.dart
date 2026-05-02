import '../core/constants/environment.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/auth_session_store.dart';
import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/erpnext_service.dart';
import '../services/mock_service.dart';

class AuthRepository {
  AuthRepository({
    MockService? mockService,
    ErpnextService? erpnextService,
    AuthSessionStore sessionStore = const AuthSessionStore(),
    bool useMockData = AppEnvironment.useMockData,
  }) : _mockService = mockService ?? MockService(),
       _erpnextService = erpnextService ?? const ErpnextService(),
       _sessionStore = sessionStore,
       _useMockData = useMockData;

  final MockService _mockService;
  final ErpnextService _erpnextService;
  final AuthSessionStore _sessionStore;
  final bool _useMockData;

  AuthService get _service => _useMockData ? _mockService : _erpnextService;

  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    try {
      final user = await _service.login(username: username, password: password);
      if (_useMockData) {
        await _sessionStore.saveMockUsername(username.trim());
      }
      return user;
    } on AppException {
      rethrow;
    } catch (error) {
      throw RepositoryException(
        'تعذر تسجيل الدخول',
        code: 'login_failed',
        cause: error,
      );
    }
  }

  Future<AppUser?> restoreSession() async {
    try {
      if (_useMockData) {
        final username = await _sessionStore.readMockUsername();
        if (username == null || username.isEmpty) return null;
        return _mockService.restoreSession(username);
      }

      return _erpnextService.getCurrentUser();
    } on AppException {
      await logout();
      return null;
    }
  }

  Future<AppUser?> getCurrentUser() async {
    return _service.getCurrentUser();
  }

  Future<void> logout() async {
    await _service.logout();
    await _sessionStore.clear();
  }
}
