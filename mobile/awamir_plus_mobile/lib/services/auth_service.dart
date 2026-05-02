import '../models/app_models.dart';

abstract class AuthService {
  Future<AppUser> login({required String username, required String password});

  Future<AppUser?> restoreSession(String sessionKey);

  Future<AppUser?> getCurrentUser();

  Future<void> logout();
}
