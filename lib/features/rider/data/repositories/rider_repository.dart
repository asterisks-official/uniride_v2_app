import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_exception_mapper.dart';
import '../../domain/models/rider_profile.dart';
import '../datasources/rider_remote_datasource.dart';

class RiderRepository {
  RiderRepository(this._remote);

  final RiderRemoteDataSource _remote;

  Future<RiderProfile?> getProfile() {
    return _guard(() async {
      final data = await _remote.getRiderProfile();
      return data == null ? null : RiderProfile.fromJson(data);
    });
  }

  /// Uploads a picked file to S3 via a presigned URL and returns its public URL.
  /// [folder] must be one of: license, vehicle_photo, student_id.
  Future<String> uploadDocument(XFile file, String folder) {
    return _guard(() async {
      final contentType = _contentTypeFor(file.name);
      final presign = await _remote.presign(folder, contentType);
      final uploadUrl = presign['uploadUrl'] as String;
      final publicUrl = presign['publicUrl'] as String;

      final bytes = await file.readAsBytes();
      // Direct PUT to S3 — a clean Dio so no auth header / base URL is attached.
      await Dio().put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': bytes.length,
          },
        ),
      );
      return publicUrl;
    });
  }

  Future<RiderProfile> submit({
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required String licensePlate,
    required String licenseDocUrl,
    required String vehiclePhotoUrl,
    String? studentIdDocUrl,
  }) {
    return _guard(() async {
      final data = await _remote.createRiderProfile({
        'vehicleType': vehicleType,
        'vehicleMake': vehicleMake,
        'vehicleModel': vehicleModel,
        'vehicleYear': vehicleYear,
        'vehicleColor': vehicleColor,
        'licensePlate': licensePlate,
        'licenseDocUrl': licenseDocUrl,
        'vehiclePhotoUrl': vehiclePhotoUrl,
        'studentIdDocUrl': ?studentIdDocUrl,
      });
      return RiderProfile.fromJson(data);
    });
  }

  String _contentTypeFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
