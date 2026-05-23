import 'package:dio/dio.dart';

import '../../../../core/network/api_exception_mapper.dart';
import '../../domain/models/pagination.dart';
import '../../domain/models/ride.dart';
import '../../domain/models/ride_request.dart';
import '../datasources/rides_remote_datasource.dart';

class RidesRepository {
  RidesRepository(this._remote);

  final RidesRemoteDataSource _remote;

  // ── Feed ─────────────────────────────────────────────────────────────────────

  Future<PagedResult<Ride>> searchRides({
    String? date,
    String? genderPref,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final data = await _remote.searchRides(
        date: date,
        genderPref: genderPref,
        page: page,
        limit: limit,
      );
      return _parseRidesPage(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<Ride> getRide(String rideId) async {
    try {
      final data = await _remote.getRide(rideId);
      return Ride.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<PagedResult<Ride>> getMyRides({
    String? role,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final data = await _remote.getMyRides(
        role: role,
        status: status,
        page: page,
        limit: limit,
      );
      return _parseRidesPage(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // ── Create ────────────────────────────────────────────────────────────────────

  Future<String> createRide({
    required String originAddress,
    required String destAddress,
    required double fare,
    required String scheduledAt, // ISO-8601
    String type = 'OFFER',
    int seatsAvailable = 1,
    String genderPref = 'ANY',
    double originLat = 0,
    double originLng = 0,
    double destLat = 0,
    double destLng = 0,
  }) async {
    try {
      final data = await _remote.createRide({
        'type': type,
        'originAddress': originAddress,
        'originLat': originLat,
        'originLng': originLng,
        'destAddress': destAddress,
        'destLat': destLat,
        'destLng': destLng,
        'fare': fare,
        'seatsAvailable': seatsAvailable,
        'genderPref': genderPref,
        'scheduledAt': scheduledAt,
      });
      return data['id'] as String;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // ── Passenger actions ─────────────────────────────────────────────────────────

  Future<RideRequest> requestRide(String rideId, {String? message}) async {
    try {
      final data = await _remote.requestRide(rideId, message: message);
      return RideRequest.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // ── Rider request management ──────────────────────────────────────────────────

  Future<List<RideRequest>> getRideRequests(String rideId) async {
    try {
      final list = await _remote.getRideRequests(rideId);
      return list
          .map((e) => RideRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<void> respondToRequest(
    String rideId,
    String requestId,
    String action,
  ) async {
    try {
      await _remote.respondToRequest(rideId, requestId, action);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // ── Ride lifecycle ────────────────────────────────────────────────────────────

  Future<void> startRide(String rideId) async {
    try {
      await _remote.startRide(rideId);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<void> cancelRide(String rideId, {String? reason}) async {
    try {
      await _remote.cancelRide(rideId, reason: reason);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<void> confirmRide(String rideId) async {
    try {
      await _remote.confirmRide(rideId);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  PagedResult<Ride> _parseRidesPage(Map<String, dynamic> data) {
    final ridesJson = data['rides'] as List<dynamic>? ?? [];
    final rides =
        ridesJson.map((e) => Ride.fromJson(e as Map<String, dynamic>)).toList();
    final meta = PaginationMeta.fromJson(
      data['pagination'] as Map<String, dynamic>? ?? {},
    );
    return PagedResult(items: rides, meta: meta);
  }
}
