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
  /// [folder] must be one of: avatar, license, vehicle_photo, license_plate,
  /// student_id, selfie — the server rejects anything else.
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
    required String selfieUrl,
    String? licensePlatePhotoUrl,
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
        'selfieUrl': selfieUrl,
        'licensePlatePhotoUrl': ?licensePlatePhotoUrl,
        'studentIdDocUrl': ?studentIdDocUrl,
      });
      return RiderProfile.fromJson(data);
    });
  }

  /// Resubmits a rejected application. Null document URLs are left as they
  /// are — an applicant who only needs to replace one photo should not have to
  /// re-upload the other four.
  Future<RiderProfile> resubmit({
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required String licensePlate,
    String? licenseDocUrl,
    String? vehiclePhotoUrl,
    String? licensePlatePhotoUrl,
    String? studentIdDocUrl,
    String? selfieUrl,
  }) {
    return _guard(() async {
      final data = await _remote.updateRiderProfile({
        'vehicleType': vehicleType,
        'vehicleMake': vehicleMake,
        'vehicleModel': vehicleModel,
        'vehicleYear': vehicleYear,
        'vehicleColor': vehicleColor,
        'licensePlate': licensePlate,
        'licenseDocUrl': ?licenseDocUrl,
        'vehiclePhotoUrl': ?vehiclePhotoUrl,
        'licensePlatePhotoUrl': ?licensePlatePhotoUrl,
        'studentIdDocUrl': ?studentIdDocUrl,
        'selfieUrl': ?selfieUrl,
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
