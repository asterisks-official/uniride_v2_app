import 'package:dio/dio.dart';

import '../../../../core/network/api_exception_mapper.dart';
import '../../domain/models/place_suggestion.dart';
import '../../domain/models/saved_place.dart';

/// Place search and reverse geocoding, via the backend.
///
/// The app never talks to Google directly: a Places key shipped in an APK can
/// be extracted and spent by someone else, and proxying lets the server cache
/// the billed calls across all users and bias results to Dhaka in one place.
class GeocodingRepository {
  GeocodingRepository(this._dio);

  final Dio _dio;

  Future<List<PlaceSuggestion>> search(String query) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/places/search',
        queryParameters: {'q': query},
      );
      final rows = (res.data?['data'] as List<dynamic>?) ?? const [];
      return rows
          .map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Turns a suggestion into a point. Returns null when the place could not be
  /// resolved, which the caller should treat as "pick it on the map instead"
  /// rather than as an error worth a red banner.
  Future<PickedPlace?> resolve(PlaceSuggestion suggestion) async {
    if (suggestion.isResolved) {
      return PickedPlace(
        lat: suggestion.lat!,
        lng: suggestion.lng!,
        areaLabel: suggestion.primary,
      );
    }

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/places/resolve',
        queryParameters: {'id': suggestion.id},
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      return PickedPlace(
        lat: (data['lat'] as num).toDouble(),
        lng: (data['lng'] as num).toDouble(),
        areaLabel: data['areaLabel'] as String? ?? suggestion.primary,
      );
    } on DioException {
      return null;
    }
  }

  static String _coordinate(double lat, double lng) =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  /// What is at a dropped pin — the most specific thing there.
  ///
  /// A building, a business, a road. Not the neighbourhood: pinning a
  /// university and being told "Ashulia" helps neither the person pinning nor
  /// the rider who has to find them.
  ///
  /// Never throws: the picker calls this on every pan-settle, and a failed
  /// lookup should leave the pin usable rather than blocking the screen.
  Future<String> reverse(double lat, double lng) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/places/reverse',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final data = res.data?['data'] as Map<String, dynamic>?;
      final name = (data?['name'] ?? data?['areaLabel']) as String?;
      return (name == null || name.isEmpty) ? _coordinate(lat, lng) : name;
    } on DioException {
      // The server is unreachable, so nothing is known about this point but
      // the point itself. Say that, rather than "Dropped pin" — the pin is
      // still exact, and a coordinate shows it.
      return _coordinate(lat, lng);
    }
  }
}
