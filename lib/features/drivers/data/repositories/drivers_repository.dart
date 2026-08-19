import 'package:dio/dio.dart';

import '../../../../core/network/api_exception_mapper.dart';
import '../../domain/models/driver_availability.dart';

class DriversRepository {
  DriversRepository(this._dio);

  final Dio _dio;

  Future<DriverAvailability> getMine() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/drivers/me/availability',
      );
      return DriverAvailability.fromJson(
        res.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Going online requires a position — riders are matched by distance, so a
  /// rider without one can never be the nearest.
  Future<DriverAvailability> setOnline({
    required bool isOnline,
    double? lat,
    double? lng,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/drivers/me/availability',
        data: {'isOnline': isOnline, 'lat': ?lat, 'lng': ?lng},
      );
      return DriverAvailability.fromJson(
        res.data?['data'] as Map<String, dynamic>? ?? const {},
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// A position update. Never throws for the caller's sake — a dropped
  /// heartbeat is expected on a moving phone, and the staleness window on the
  /// server is what handles a run of them.
  Future<void> heartbeat({required double lat, required double lng}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/drivers/me/location',
        data: {'lat': lat, 'lng': lng},
      );
    } on DioException {
      // Deliberately swallowed.
    }
  }
}
