import 'package:dio/dio.dart';

class PlacesRemoteDataSource {
  PlacesRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<dynamic>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/saved-places');
    return (res.data?['data'] as List<dynamic>?) ?? const [];
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/saved-places',
      data: body,
    );
    return _data(res);
  }

  Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/saved-places/$id',
      data: body,
    );
    return _data(res);
  }

  Future<void> remove(String id) async {
    await _dio.delete<void>('/saved-places/$id');
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> res) =>
      (res.data?['data'] as Map<String, dynamic>?) ?? const {};
}
