import 'package:dio/dio.dart';

class RidesRemoteDataSource {
  RidesRemoteDataSource(this._dio);

  final Dio _dio;

  // ── Feed ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> searchRides({
    String? date,
    String? genderPref,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/rides',
      queryParameters: {
        'date': ?date,
        'genderPref': ?genderPref,
        'page': page,
        'limit': limit,
      },
    );
    return _data(res);
  }

  Future<Map<String, dynamic>> getRide(String rideId) async {
    final res = await _dio.get<Map<String, dynamic>>('/rides/$rideId');
    return _data(res);
  }

  Future<Map<String, dynamic>> getMyRides({
    String? role,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/rides/my',
      queryParameters: {
        'role': ?role,
        'status': ?status,
        'page': page,
        'limit': limit,
      },
    );
    return _data(res);
  }

  // ── Create (RIDER only) ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createRide(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>('/rides', data: body);
    return _data(res);
  }

  // ── Passenger actions ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> requestRide(
    String rideId, {
    String? message,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/rides/$rideId/requests',
      data: {
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return _data(res);
  }

  // ── Rider request management ──────────────────────────────────────────────────

  Future<List<dynamic>> getRideRequests(String rideId) async {
    final res = await _dio.get<Map<String, dynamic>>('/rides/$rideId/requests');
    final body = res.data;
    final data = body?['data'];
    if (data is List) return data;
    return const [];
  }

  Future<Map<String, dynamic>> respondToRequest(
    String rideId,
    String requestId,
    String action, // 'ACCEPT' | 'DECLINE'
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/rides/$rideId/requests/$requestId',
      data: {'action': action},
    );
    return _data(res);
  }

  // ── Ride lifecycle ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startRide(String rideId) async {
    final res =
        await _dio.patch<Map<String, dynamic>>('/rides/$rideId/start');
    return _data(res);
  }

  Future<Map<String, dynamic>> cancelRide(String rideId, {String? reason}) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/rides/$rideId',
      data: {'reason': ?reason},
    );
    return _data(res);
  }

  Future<Map<String, dynamic>> confirmRide(String rideId) async {
    final res =
        await _dio.patch<Map<String, dynamic>>('/rides/$rideId/confirm');
    return _data(res);
  }

  // ── Helper ────────────────────────────────────────────────────────────────────

  Map<String, dynamic> _data(Response<Map<String, dynamic>> res) {
    final body = res.data;
    final data = body?['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }
}
