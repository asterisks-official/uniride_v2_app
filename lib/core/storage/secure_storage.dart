import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kUserJson = 'user_json';
  static const _kRememberMe = 'remember_me';

  Future<String?> readAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<String?> readUserJson() => _storage.read(key: _kUserJson);
  Future<void> saveUserJson(String json) =>
      _storage.write(key: _kUserJson, value: json);

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
    await _storage.delete(key: _kRememberMe);
  }
}
