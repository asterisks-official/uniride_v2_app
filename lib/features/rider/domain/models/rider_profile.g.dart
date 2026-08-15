// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RiderProfile _$RiderProfileFromJson(Map<String, dynamic> json) =>
    _RiderProfile(
      id: json['id'] as String,
      vehicleType: json['vehicleType'] as String,
      vehicleMake: json['vehicleMake'] as String,
      vehicleModel: json['vehicleModel'] as String,
      vehicleYear: (json['vehicleYear'] as num).toInt(),
      vehicleColor: json['vehicleColor'] as String,
      licensePlate: json['licensePlate'] as String,
      verificationStatus: json['verificationStatus'] as String,
      adminNote: json['adminNote'] as String?,
      rejectionCount: (json['rejectionCount'] as num?)?.toInt() ?? 0,
      licenseDocUrl: json['licenseDocUrl'] as String?,
      vehiclePhotoUrl: json['vehiclePhotoUrl'] as String?,
      licensePlatePhotoUrl: json['licensePlatePhotoUrl'] as String?,
      studentIdDocUrl: json['studentIdDocUrl'] as String?,
      selfieUrl: json['selfieUrl'] as String?,
      faceVerifiedAt: json['faceVerifiedAt'] == null
          ? null
          : DateTime.parse(json['faceVerifiedAt'] as String),
    );

Map<String, dynamic> _$RiderProfileToJson(_RiderProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'vehicleType': instance.vehicleType,
      'vehicleMake': instance.vehicleMake,
      'vehicleModel': instance.vehicleModel,
      'vehicleYear': instance.vehicleYear,
      'vehicleColor': instance.vehicleColor,
      'licensePlate': instance.licensePlate,
      'verificationStatus': instance.verificationStatus,
      'adminNote': instance.adminNote,
      'rejectionCount': instance.rejectionCount,
      'licenseDocUrl': instance.licenseDocUrl,
      'vehiclePhotoUrl': instance.vehiclePhotoUrl,
      'licensePlatePhotoUrl': instance.licensePlatePhotoUrl,
      'studentIdDocUrl': instance.studentIdDocUrl,
      'selfieUrl': instance.selfieUrl,
      'faceVerifiedAt': instance.faceVerifiedAt?.toIso8601String(),
    };
