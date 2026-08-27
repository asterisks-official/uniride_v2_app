import 'package:dio/dio.dart';

import '../../../../core/network/api_exception_mapper.dart';
import '../../../places/domain/models/campus.dart';
import '../../../places/domain/models/saved_place.dart';
import '../../domain/models/pagination.dart';
import '../../domain/models/ride.dart';
import '../../domain/models/ride_quote.dart';
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

  Future<void> startRide(String rideId, {double? lat, double? lng}) async {
    try {
      await _remote.startRide(rideId, lat: lat, lng: lng);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// The passenger's half of starting. Until this lands the ride is matched
  /// but not under way.
  Future<void> confirmStart(String rideId, {double? lat, double? lng}) async {
    try {
      await _remote.confirmStart(rideId, lat: lat, lng: lng);
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

  /// Returns the ride's status after the confirmation lands.
  ///
  /// The caller needs it: a confirmation that completes the ride sends both
  /// people on to payment, and one that does not leaves them waiting for the
  /// other side. Waiting for the server to say so over the socket makes the
  /// person who just tapped depend on a round-trip to learn what their own tap
  /// did — the answer is already in this response.
  Future<String?> confirmRide(String rideId, {double? lat, double? lng}) async {
    try {
      final data = await _remote.confirmRide(rideId, lat: lat, lng: lng);
      return data['status'] as String?;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // ── Ride creation, campus shape ───────────────────────────────────────────────

  /// What a trip between [lat]/[lng] and a campus costs.
  ///
  /// The client sends coordinates and gets back a price. It never computes one
  /// — two devices would disagree, and the disagreement would surface as a
  /// rider and a passenger seeing different numbers for the same ride.
  Future<RideQuote> quote({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final data = await _remote.quoteRide({
        'fromLat': fromLat,
        'fromLng': fromLng,
        'toLat': toLat,
        'toLng': toLng,
      });
      return RideQuote.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Posts a trip: two real points, priced server-side.
  ///
  /// One call for both modes. `INSTANT` omits [scheduledAt] and the server
  /// stamps the request time; `SCHEDULED` requires it.
  Future<String> createTrip({
    required String type,
    required String mode,
    required PickedPlace pickup,
    required PickedPlace destination,
    String? scheduledAt,
    String genderPref = 'ANY',
  }) async {
    try {
      final data = await _remote.createRide({
        'type': type,
        'mode': mode,
        'pickup': _point(pickup),
        'destination': _point(destination),
        'scheduledAt': ?scheduledAt,
        'genderPref': genderPref,
        // No fare and no seat count: the server prices the trip, and launch is
        // bike-only so every ride carries one.
      });
      return data['id'] as String;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Map<String, dynamic> _point(PickedPlace place) => {
    'lat': place.lat,
    'lng': place.lng,
    'address': place.displayName,
    'areaLabel': place.areaLabel,
  };

  Future<List<University>> myUniversities() async {
    try {
      final rows = await _remote.myUniversities();
      return rows
          .map((e) => University.fromJson(e as Map<String, dynamic>))
          .toList();
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
