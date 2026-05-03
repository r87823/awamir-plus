class AppEnvironment {
  const AppEnvironment._();

  static const useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: false,
  );

  static const baseUrl = String.fromEnvironment(
    'ERPNEXT_BASE_URL',
    defaultValue: 'https://awamirplus.r8787m.cc',
  );

  static const apiPrefix = String.fromEnvironment(
    'ERPNEXT_API_PREFIX',
    defaultValue: '/api/method',
  );

  static const timeoutSeconds = int.fromEnvironment(
    'ERPNEXT_TIMEOUT_SECONDS',
    defaultValue: 30,
  );

  static const requestTimeout = Duration(seconds: timeoutSeconds);
}
