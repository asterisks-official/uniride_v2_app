import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';

class ApiClient {
  ApiClient({
    required SecureStorage storage,
    void Function()? onSessionExpired,
  }) {
    final base = BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    );

    // Separate Dio used by the interceptor for refresh + retry (no auth interceptor).
    final refreshDio = Dio(base);

    _dio = Dio(base)
      ..interceptors.add(
        AuthInterceptor(
          storage: storage,
          refreshDio: refreshDio,
          onSessionExpired: onSessionExpired,
        ),
      );
  }

  late final Dio _dio;

  Dio get dio => _dio;
}
