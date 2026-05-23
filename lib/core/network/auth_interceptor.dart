import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';

/// Attaches the access token to every request and, on a 401, attempts a single
/// token refresh then retries the original request. If refresh fails, tokens are
/// cleared and [onSessionExpired] is invoked so the app can route to login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required SecureStorage storage,
    required Dio refreshDio,
    this.onSessionExpired,
  })  : _storage = storage,
        _refreshDio = refreshDio;

  final SecureStorage _storage;
  // A bare Dio (no AuthInterceptor) used only to hit /auth/refresh.
  final Dio _refreshDio;
  final void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true) {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['retried'] == true;
    final isRefreshCall = err.requestOptions.extra['skipAuth'] == true;

    if (!isUnauthorized || alreadyRetried || isRefreshCall) {
      return handler.next(err);
    }

    final refreshed = await _runRefresh();
    if (!refreshed) {
      await _storage.clear();
      onSessionExpired?.call();
      return handler.next(err);
    }

    try {
      final token = await _storage.readAccessToken();
      final opts = err.requestOptions
        ..extra['retried'] = true
        ..headers['Authorization'] = 'Bearer $token';
      final response = await _refreshDio.fetch<dynamic>(opts);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Ensures only one refresh runs at a time even if many requests 401 together.
  Future<bool> _runRefresh() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _refresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      final newAccess = data?['accessToken'] as String?;
      final newRefresh = data?['refreshToken'] as String?;
      if (newAccess == null || newRefresh == null) return false;

      await _storage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh,
      );
      return true;
    } on DioException {
      return false;
    }
  }
}
