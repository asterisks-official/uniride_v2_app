import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kUserJson = 'user_json';
  static const _kUserJsonVersion = 'user_json_version';
  static const _kRememberMe = 'remember_me';

  /// Bump whenever a field is added to `User`.
  ///
  /// The cached user is trusted on cold start in place of a network call, so a
  /// record written by an older build is served as if it were current — and a
  /// field that build never knew about silently reads as its default. That is
  /// how a rider whose application is under review ended up let into the app:
  /// their cache predated `signedUpAsRider`, so it decoded as false and the
  /// gate had nothing to act on. A stale cache is discarded instead.
  static const _userCacheVersion = '2';

  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  /// Null when nothing is cached *or* the cache was written by a build with a
  /// different `User` shape, so callers fall through to fetching a fresh one.
  Future<String?> readUserJson() async {
    final version = await _storage.read(key: _kUserJsonVersion);
    if (version != _userCacheVersion) return null;
    return _storage.read(key: _kUserJson);
  }

  Future<void> saveUserJson(String json) async {
    await _storage.write(key: _kUserJson, value: json);
    await _storage.write(key: _kUserJsonVersion, value: _userCacheVersion);
  }

  // Defaults to true when the key is absent (first install / cleared storage).
  Future<bool> readRememberMe() async {
    final val = await _storage.read(key: _kRememberMe);
    return val != 'false';
  }

  Future<void> saveRememberMe(bool value) =>
      _storage.write(key: _kRememberMe, value: value.toString());

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  Future<void> saveAccessToken(String accessToken) =>
      _storage.write(key: _kAccessToken, value: accessToken);

  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kUserJson);
    await _storage.delete(key: _kUserJsonVersion);
    await _storage.delete(key: _kRememberMe);
  }
}
