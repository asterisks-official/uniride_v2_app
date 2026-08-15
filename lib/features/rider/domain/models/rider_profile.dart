import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/constants/app_constants.dart';

part 'rider_profile.freezed.dart';
part 'rider_profile.g.dart';

@freezed
abstract class RiderProfile with _$RiderProfile {
  const factory RiderProfile({
    required String id,
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required int vehicleYear,
    required String vehicleColor,
    required String licensePlate,
    required String verificationStatus, // PENDING | APPROVED | REJECTED
    String? adminNote,

    /// How many times this application has been rejected. At
    /// [AppConstants.maxRiderRejections] the account is blocked outright.
    @Default(0) int rejectionCount,

    // Document URLs, so a resubmission can tell which slots are already filled
    // and only re-upload what the applicant actually replaces.
    String? licenseDocUrl,
    String? vehiclePhotoUrl,
    String? licensePlatePhotoUrl,
    String? studentIdDocUrl,
    String? selfieUrl,

    /// When the live face check passed. Null on profiles created before face
    /// verification existed.
    DateTime? faceVerifiedAt,
  }) = _RiderProfile;

  const RiderProfile._();

  bool get isRejected => verificationStatus == 'REJECTED';

  /// Resubmissions left before the account is blocked.
  int get attemptsLeft =>
      (AppConstants.maxRiderRejections - rejectionCount).clamp(0, 99);

  factory RiderProfile.fromJson(Map<String, dynamic> json) =>
      _$RiderProfileFromJson(json);
}
