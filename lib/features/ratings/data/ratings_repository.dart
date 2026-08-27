import 'package:dio/dio.dart';

import '../../../core/network/api_exception_mapper.dart';

/// Ratings, which only exist for rides that are over.
///
/// Who is being rated is not sent: the server derives it from the ride and the
/// caller. A client that could name the ratee could name somebody who was
/// never on the trip.
class RatingsRepository {
  RatingsRepository(this._dio);

  final Dio _dio;

  Future<void> submit({
    required String rideId,
    required int score,
    String? review,
    List<String> tags = const [],
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/ratings',
        data: {
          'rideId': rideId,
          'score': score,
          if (review != null && review.trim().isNotEmpty) 'review': review.trim(),
          if (tags.isNotEmpty) 'tags': tags,
        },
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Whether this user has already rated this ride.
  ///
  /// The server refuses a second rating with a 409, but arriving at a form,
  /// filling it in and being told afterwards is a worse way to find out.
  Future<bool> hasRated(String rideId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/ratings/ride/$rideId');
      final data = res.data?['data'];
      if (data is Map) return data['mine'] != null || data['yours'] != null;
      if (data is List) return data.isNotEmpty;
      return false;
    } on DioException {
      // Not knowing is not a reason to block the form; the submit still guards.
      return false;
    }
  }
}
