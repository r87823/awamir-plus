class AppEnvironment {
  const AppEnvironment._();

  static const useMockData = true;

  static const erpnextBaseUrl = String.fromEnvironment(
    'ERPNEXT_BASE_URL',
    defaultValue: '',
  );

  static const erpnextApiVersion = String.fromEnvironment(
    'ERPNEXT_API_VERSION',
    defaultValue: 'v1',
  );

  static const requestTimeout = Duration(seconds: 30);
}
