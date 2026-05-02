class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => code == null ? message : '$message ($code)';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.cause});
}

class RepositoryException extends AppException {
  const RepositoryException(super.message, {super.code, super.cause});
}
