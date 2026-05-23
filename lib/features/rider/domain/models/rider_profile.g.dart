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
    };
