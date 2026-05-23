import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/network/api_exception_mapper.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../domain/models/user.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remote,
    required SecureStorage storage,
  })  : _remote = remote,
        _storage = storage;

  final AuthRemoteDataSource _remote;
  final SecureStorage _storage;

  /// Registers and stores the short-lived access token so the subsequent
  /// (guarded) verify-email call is authenticated. Returns the dev OTP if the
  /// backend is running in non-production mode.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? university,
    String? phone,
  }) {
    return _guard(() async {
      final data = await _remote.register(
        name: name,
        email: email,
        password: password,
        university: university,
        phone: phone,
      );
      final accessToken = data['accessToken'] as String?;
      if (accessToken != null) await _storage.saveAccessToken(accessToken);
      return data['devOtp'] as String?;
    });
  }

  Future<User> verifyEmail(String otp) {
    return _guard(() async {
      final data = await _remote.verifyEmail(otp);
      await _saveTokens(data);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      // Verification always implies the user wants a persistent session.
      await _storage.saveRememberMe(true);
      await _storage.saveUserJson(jsonEncode(user.toJson()));
      return user;
    });
  }

  Future<User> login({
    required String email,
    required String password,
    bool rememberMe = true,
    String? fcmToken,
    String? deviceType,
  }) {
    return _guard(() async {
      final data = await _remote.login(
        email: email,
        password: password,
        fcmToken: fcmToken,
        deviceType: deviceType,
      );
      await _saveTokens(data);
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      await _storage.saveRememberMe(rememberMe);
      // Cache the user so the next app start skips the /me network call.
      if (rememberMe) await _storage.saveUserJson(jsonEncode(user.toJson()));
      return user;
    });
  }

  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _remote.logout(refreshToken);
      } on DioException {
        // Best-effort server-side revocation; local clear is what matters.
      }
    }
    await _storage.clear();
  }

  Future<String?> forgotPassword(String email) {
    return _guard(() async {
      final data = await _remote.forgotPassword(email);
      return data['devOtp'] as String?;
    });
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _guard(() => _remote.resetPassword(
          email: email,
          otp: otp,
          newPassword: newPassword,
        ));
  }

  /// Forces a token refresh (to pick up a server-side role change, e.g. after
  /// rider approval) and returns the freshly-loaded user.
  Future<User> refreshSession() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const UnauthorizedException();
    }
    return _guard(() async {
      final tokens = await _remote.refresh(refreshToken);
      await _saveTokens(tokens);
      final me = await _remote.getMe();
      final user = User.fromJson(me);
      await _storage.saveUserJson(jsonEncode(user.toJson()));
      return user;
    });
  }

  /// Restores a session on app start.
  ///
  /// Returns immediately from the local cache when available — no network
  /// round-trip — so the splash stays on screen for milliseconds, not seconds.
  /// If `remember_me` was false the session is wiped and null is returned.
  Future<User?> tryRestoreSession() async {
    // Honour the remember-me preference: wipe session on next cold start.
    final rememberMe = await _storage.readRememberMe();
    if (!rememberMe) {
      await _storage.clear();
      return null;
    }

    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) return null;

    // Fast path: return cached user without a network round-trip.
    final cachedJson = await _storage.readUserJson();
    if (cachedJson != null) {
      try {
        return User.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt cache — fall through to network.
      }
    }

    // Slow path (no cache yet, e.g. first launch after upgrading the app).
    try {
      final data = await _remote.getMe();
      final user = User.fromJson(data);
      await _storage.saveUserJson(jsonEncode(user.toJson()));
      return user;
    } on DioException {
      await _storage.clear();
      return null;
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (accessToken != null && refreshToken != null) {
      await _storage.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
