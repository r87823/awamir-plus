import 'package:flutter/foundation.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/view_state.dart';
import '../models/app_models.dart';
import '../repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository authRepository})
    : _authRepository = authRepository {
    restoreSession();
  }

  final AuthRepository _authRepository;

  ViewState<AppUser?> authState = const ViewState.loading();
  AppUser? currentUser;
  bool hasCheckedSession = false;

  bool get isLoading => authState.isLoading;
  bool get isLoggedIn => currentUser != null && authState.isSuccess;
  String? get errorMessage => authState.isError ? authState.message : null;

  Future<void> restoreSession() async {
    authState = const ViewState.loading();
    notifyListeners();

    try {
      currentUser = await _authRepository.restoreSession();
      authState = ViewState.success(currentUser);
    } catch (error) {
      currentUser = null;
      authState = const ViewState.success(null);
    }

    hasCheckedSession = true;
    notifyListeners();
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    authState = const ViewState.loading();
    notifyListeners();

    try {
      currentUser = await _authRepository.login(
        username: username,
        password: password,
      );
      authState = ViewState.success(currentUser);
      notifyListeners();
      return true;
    } on AppException catch (error) {
      currentUser = null;
      authState = ViewState.error(error.message);
    } catch (error) {
      currentUser = null;
      authState = const ViewState.error('تعذر تسجيل الدخول');
    }

    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    authState = const ViewState.loading();
    notifyListeners();

    await _authRepository.logout();
    currentUser = null;
    authState = const ViewState.success(null);
    notifyListeners();
  }
}
