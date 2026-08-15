import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/providers.dart';
import '../../data/repositories/rider_repository.dart';
import '../../domain/models/rider_profile.dart';

class RiderNotifier extends AsyncNotifier<RiderProfile?> {
  RiderRepository get _repo => ref.read(riderRepositoryProvider);

  @override
  Future<RiderProfile?> build() {
    return ref.watch(riderRepositoryProvider).getProfile();
  }

  /// Uploads documents then creates the rider profile. Throws [AppException]
  /// on failure; sets the new profile as state on success.
  ///
  /// [onStage] is called before each upload. Five files over a campus
  /// connection is long enough that a single unchanging spinner reads as a
  /// hang, so the caller can narrate what is actually happening.
  Future<void> submit({
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required String licensePlate,
    required XFile licenseDoc,
    required XFile vehiclePhoto,
    required XFile licensePlatePhoto,
    required XFile studentIdDoc,
    required XFile selfie,
    void Function(String stage)? onStage,
  }) async {
    onStage?.call('Uploading your licence');
    final licenseUrl = await _repo.uploadDocument(licenseDoc, 'license');

    onStage?.call('Uploading your student ID');
    final studentIdUrl = await _repo.uploadDocument(studentIdDoc, 'student_id');

    onStage?.call('Uploading your vehicle photo');
    final vehicleUrl = await _repo.uploadDocument(
      vehiclePhoto,
      'vehicle_photo',
    );

    onStage?.call('Uploading your plate photo');
    final plateUrl = await _repo.uploadDocument(
      licensePlatePhoto,
      'license_plate',
    );

    onStage?.call('Uploading your face check');
    final selfieUrl = await _repo.uploadDocument(selfie, 'selfie');

    onStage?.call('Submitting your application');
    final profile = await _repo.submit(
      vehicleType: vehicleType,
      vehicleMake: vehicleMake,
      vehicleModel: vehicleModel,
      vehicleYear: vehicleYear,
      vehicleColor: vehicleColor,
      licensePlate: licensePlate,
      licenseDocUrl: licenseUrl,
      vehiclePhotoUrl: vehicleUrl,
      licensePlatePhotoUrl: plateUrl,
      studentIdDocUrl: studentIdUrl,
      selfieUrl: selfieUrl,
    );
    state = AsyncData(profile);
  }

  /// Resubmits a rejected application. A null [XFile] means "keep what is
  /// already on file", so only replaced documents are uploaded.
  Future<void> resubmit({
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required String licensePlate,
    XFile? licenseDoc,
    XFile? vehiclePhoto,
    XFile? licensePlatePhoto,
    XFile? studentIdDoc,
    XFile? selfie,
    void Function(String stage)? onStage,
  }) async {
    Future<String?> upload(XFile? file, String folder, String stage) async {
      if (file == null) return null;
      onStage?.call(stage);
      return _repo.uploadDocument(file, folder);
    }

    final licenseUrl = await upload(
      licenseDoc,
      'license',
      'Uploading your licence',
    );
    final studentIdUrl = await upload(
      studentIdDoc,
      'student_id',
      'Uploading your student ID',
    );
    final vehicleUrl = await upload(
      vehiclePhoto,
      'vehicle_photo',
      'Uploading your vehicle photo',
    );
    final plateUrl = await upload(
      licensePlatePhoto,
      'license_plate',
      'Uploading your plate photo',
    );
    final selfieUrl = await upload(
      selfie,
      'selfie',
      'Uploading your face check',
    );

    onStage?.call('Resubmitting your application');
    final profile = await _repo.resubmit(
      vehicleType: vehicleType,
      vehicleMake: vehicleMake,
      vehicleModel: vehicleModel,
      vehicleYear: vehicleYear,
      vehicleColor: vehicleColor,
      licensePlate: licensePlate,
      licenseDocUrl: licenseUrl,
      vehiclePhotoUrl: vehicleUrl,
      licensePlatePhotoUrl: plateUrl,
      studentIdDocUrl: studentIdUrl,
      selfieUrl: selfieUrl,
    );
    state = AsyncData(profile);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getProfile());
  }
}

final riderNotifierProvider =
    AsyncNotifierProvider<RiderNotifier, RiderProfile?>(RiderNotifier.new);
