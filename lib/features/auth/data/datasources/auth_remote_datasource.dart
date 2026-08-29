import 'package:dio/dio.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String gender,
    required String studentIdNumber,
    required String joinAs,
    String? university,
    String? phone,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'gender': gender,
        'studentIdNumber': studentIdNumber,
        'joinAs': joinAs,
        if (university != null && university.isNotEmpty) 'university': university,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    return _data(res);
  }

  /// Switch which side of the market the user browses.
  ///
  /// Returns a fresh token pair: the mode is carried in the JWT, so the old
  /// token would keep serving the previous side of the feed.
  Future<Map<String, dynamic>> switchMode(String mode) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/users/me/active-mode',
      data: {'mode': mode},
    );
    return _data(res);
  }

  /// Fill in fields that predate them being required at signup.
  Future<Map<String, dynamic>> completeProfile({
    required String gender,
    required String studentIdNumber,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/users/me',
      data: {'gender': gender, 'studentIdNumber': studentIdNumber},
    );
    return _data(res);
  }

  Future<Map<String, dynamic>> verifyEmail(String otp) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/verify-email',
      data: {'otp': otp},
    );
    return _data(res);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String? fcmToken,
    String? deviceType,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
        'fcmToken': ?fcmToken,
        'deviceType': ?deviceType,
      },
    );
    return _data(res);
  }

  /// Registers this install for push, or updates the token FCM has rotated.
  Future<void> registerDevice({
    required String fcmToken,
    required String deviceType,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/auth/devices',
      data: {'fcmToken': fcmToken, 'deviceType': deviceType},
    );
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
      options: Options(extra: {'skipAuth': true}),
    );
    return _data(res);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post<Map<String, dynamic>>(
      '/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      data: {'email': email},
    );
    return _data(res);
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/auth/reset-password',
      data: {'email': email, 'otp': otp, 'newPassword': newPassword},
    );
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me');
    return _data(res);
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> res) {
    final body = res.data;
    final data = body?['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}
