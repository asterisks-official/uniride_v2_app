import 'package:freezed_annotation/freezed_annotation.dart';

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
  }) = _RiderProfile;

  factory RiderProfile.fromJson(Map<String, dynamic> json) =>
      _$RiderProfileFromJson(json);
}
