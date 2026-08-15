import 'package:dio/dio.dart';

class RiderRemoteDataSource {
  RiderRemoteDataSource(this._dio);

  final Dio _dio;

  /// Returns the current user's rider profile, or null if they don't have one.
  Future<Map<String, dynamic>?> getRiderProfile() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/users/me/rider-profile',
      );
      return _data(res);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createRiderProfile(
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/users/me/rider-profile',
      data: body,
    );
    return _data(res);
  }

  /// Corrects an existing profile. A rejected one goes back to PENDING for
  /// another review; only the keys present in [body] are changed.
  Future<Map<String, dynamic>> updateRiderProfile(
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/users/me/rider-profile',
      data: body,
    );
    return _data(res);
  }

  /// Returns { uploadUrl, publicUrl, key }.
  Future<Map<String, dynamic>> presign(
    String folder,
    String contentType,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/uploads/presign',
      data: {'folder': folder, 'contentType': contentType},
    );
    return _data(res);
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> res) {
    final data = res.data?['data'];
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }
}
