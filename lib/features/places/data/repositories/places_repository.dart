import 'package:dio/dio.dart';

import '../../../../core/network/api_exception_mapper.dart';
import '../../domain/models/saved_place.dart';
import '../datasources/places_remote_datasource.dart';

class PlacesRepository {
  PlacesRepository(this._remote);

  final PlacesRemoteDataSource _remote;

  Future<List<SavedPlace>> list() async {
    try {
      final rows = await _remote.list();
      return rows
          .map((e) => SavedPlace.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<SavedPlace> create({
    required String label,
    required double lat,
    required double lng,
    required String areaLabel,
  }) async {
    try {
      final data = await _remote.create({
        'label': label,
        'lat': lat,
        'lng': lng,
        'areaLabel': areaLabel,
      });
      return SavedPlace.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<SavedPlace> update(
    String id, {
    required String label,
    required double lat,
    required double lng,
    required String areaLabel,
  }) async {
    try {
      final data = await _remote.update(id, {
        'label': label,
        'lat': lat,
        'lng': lng,
        'areaLabel': areaLabel,
      });
      return SavedPlace.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  Future<void> remove(String id) async {
    try {
      await _remote.remove(id);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
