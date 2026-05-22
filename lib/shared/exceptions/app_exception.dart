sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException() : super('Session expired. Please log in again.');
}

class ServerException extends AppException {
  final int? statusCode;
  const ServerException(super.message, {this.statusCode});
}

class ValidationException extends AppException {
  final List<String> errors;
  const ValidationException(super.message, {this.errors = const []});
}

class CacheException extends AppException {
  const CacheException(super.message);
}
