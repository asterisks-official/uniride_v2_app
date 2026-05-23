import 'package:dio/dio.dart';

import '../../shared/exceptions/app_exception.dart';

/// Translates a [DioException] into the app's [AppException] hierarchy,
/// extracting the backend error envelope:
/// `{ statusCode, error, message: string[], ... }`.
AppException mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return const NetworkException(
        'Could not reach the server. Check your connection.',
      );
    case DioExceptionType.badCertificate:
      return const NetworkException('Secure connection failed.');
    case DioExceptionType.cancel:
      return const NetworkException('Request cancelled.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }

  final status = e.response?.statusCode;
  final messages = _messages(e.response?.data);
  final message = messages.isNotEmpty
      ? messages.first
      : (e.message ?? 'Something went wrong.');

  if (status == 401) {
    return UnauthorizedException(messages.isNotEmpty ? message : null);
  }
  if (status == 400 || status == 422) {
    return ValidationException(message, errors: messages);
  }
  return ServerException(message, statusCode: status);
}

List<String> _messages(dynamic data) {
  if (data is! Map) return const [];
  final raw = data['message'];
  if (raw is String) return [raw];
  if (raw is List) return raw.map((e) => e.toString()).toList();
  return const [];
}
