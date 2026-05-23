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
  Future<void> submit({
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required String licensePlate,
    required XFile licenseDoc,
    required XFile vehiclePhoto,
    XFile? studentIdDoc,
  }) async {
    final licenseUrl = await _repo.uploadDocument(licenseDoc, 'license');
    final vehicleUrl = await _repo.uploadDocument(vehiclePhoto, 'vehicle_photo');
    final studentIdUrl = studentIdDoc != null
        ? await _repo.uploadDocument(studentIdDoc, 'student_id')
        : null;

    final profile = await _repo.submit(
      vehicleType: vehicleType,
      vehicleMake: vehicleMake,
      vehicleModel: vehicleModel,
      vehicleYear: vehicleYear,
      vehicleColor: vehicleColor,
      licensePlate: licensePlate,
      licenseDocUrl: licenseUrl,
      vehiclePhotoUrl: vehicleUrl,
      studentIdDocUrl: studentIdUrl,
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
