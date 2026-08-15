// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rider_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RiderProfile {

 String get id; String get vehicleType; String get vehicleMake; String get vehicleModel; int get vehicleYear; String get vehicleColor; String get licensePlate; String get verificationStatus;// PENDING | APPROVED | REJECTED
 String? get adminNote;/// How many times this application has been rejected. At
/// [AppConstants.maxRiderRejections] the account is blocked outright.
 int get rejectionCount;// Document URLs, so a resubmission can tell which slots are already filled
// and only re-upload what the applicant actually replaces.
 String? get licenseDocUrl; String? get vehiclePhotoUrl; String? get licensePlatePhotoUrl; String? get studentIdDocUrl; String? get selfieUrl;/// When the live face check passed. Null on profiles created before face
/// verification existed.
 DateTime? get faceVerifiedAt;
/// Create a copy of RiderProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RiderProfileCopyWith<RiderProfile> get copyWith => _$RiderProfileCopyWithImpl<RiderProfile>(this as RiderProfile, _$identity);

  /// Serializes this RiderProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RiderProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.vehicleMake, vehicleMake) || other.vehicleMake == vehicleMake)&&(identical(other.vehicleModel, vehicleModel) || other.vehicleModel == vehicleModel)&&(identical(other.vehicleYear, vehicleYear) || other.vehicleYear == vehicleYear)&&(identical(other.vehicleColor, vehicleColor) || other.vehicleColor == vehicleColor)&&(identical(other.licensePlate, licensePlate) || other.licensePlate == licensePlate)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.adminNote, adminNote) || other.adminNote == adminNote)&&(identical(other.rejectionCount, rejectionCount) || other.rejectionCount == rejectionCount)&&(identical(other.licenseDocUrl, licenseDocUrl) || other.licenseDocUrl == licenseDocUrl)&&(identical(other.vehiclePhotoUrl, vehiclePhotoUrl) || other.vehiclePhotoUrl == vehiclePhotoUrl)&&(identical(other.licensePlatePhotoUrl, licensePlatePhotoUrl) || other.licensePlatePhotoUrl == licensePlatePhotoUrl)&&(identical(other.studentIdDocUrl, studentIdDocUrl) || other.studentIdDocUrl == studentIdDocUrl)&&(identical(other.selfieUrl, selfieUrl) || other.selfieUrl == selfieUrl)&&(identical(other.faceVerifiedAt, faceVerifiedAt) || other.faceVerifiedAt == faceVerifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,vehicleType,vehicleMake,vehicleModel,vehicleYear,vehicleColor,licensePlate,verificationStatus,adminNote,rejectionCount,licenseDocUrl,vehiclePhotoUrl,licensePlatePhotoUrl,studentIdDocUrl,selfieUrl,faceVerifiedAt);

@override
String toString() {
  return 'RiderProfile(id: $id, vehicleType: $vehicleType, vehicleMake: $vehicleMake, vehicleModel: $vehicleModel, vehicleYear: $vehicleYear, vehicleColor: $vehicleColor, licensePlate: $licensePlate, verificationStatus: $verificationStatus, adminNote: $adminNote, rejectionCount: $rejectionCount, licenseDocUrl: $licenseDocUrl, vehiclePhotoUrl: $vehiclePhotoUrl, licensePlatePhotoUrl: $licensePlatePhotoUrl, studentIdDocUrl: $studentIdDocUrl, selfieUrl: $selfieUrl, faceVerifiedAt: $faceVerifiedAt)';
}


}

/// @nodoc
abstract mixin class $RiderProfileCopyWith<$Res>  {
  factory $RiderProfileCopyWith(RiderProfile value, $Res Function(RiderProfile) _then) = _$RiderProfileCopyWithImpl;
@useResult
$Res call({
 String id, String vehicleType, String vehicleMake, String vehicleModel, int vehicleYear, String vehicleColor, String licensePlate, String verificationStatus, String? adminNote, int rejectionCount, String? licenseDocUrl, String? vehiclePhotoUrl, String? licensePlatePhotoUrl, String? studentIdDocUrl, String? selfieUrl, DateTime? faceVerifiedAt
});




}
/// @nodoc
class _$RiderProfileCopyWithImpl<$Res>
    implements $RiderProfileCopyWith<$Res> {
  _$RiderProfileCopyWithImpl(this._self, this._then);

  final RiderProfile _self;
  final $Res Function(RiderProfile) _then;

/// Create a copy of RiderProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? vehicleType = null,Object? vehicleMake = null,Object? vehicleModel = null,Object? vehicleYear = null,Object? vehicleColor = null,Object? licensePlate = null,Object? verificationStatus = null,Object? adminNote = freezed,Object? rejectionCount = null,Object? licenseDocUrl = freezed,Object? vehiclePhotoUrl = freezed,Object? licensePlatePhotoUrl = freezed,Object? studentIdDocUrl = freezed,Object? selfieUrl = freezed,Object? faceVerifiedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as String,vehicleMake: null == vehicleMake ? _self.vehicleMake : vehicleMake // ignore: cast_nullable_to_non_nullable
as String,vehicleModel: null == vehicleModel ? _self.vehicleModel : vehicleModel // ignore: cast_nullable_to_non_nullable
as String,vehicleYear: null == vehicleYear ? _self.vehicleYear : vehicleYear // ignore: cast_nullable_to_non_nullable
as int,vehicleColor: null == vehicleColor ? _self.vehicleColor : vehicleColor // ignore: cast_nullable_to_non_nullable
as String,licensePlate: null == licensePlate ? _self.licensePlate : licensePlate // ignore: cast_nullable_to_non_nullable
as String,verificationStatus: null == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as String,adminNote: freezed == adminNote ? _self.adminNote : adminNote // ignore: cast_nullable_to_non_nullable
as String?,rejectionCount: null == rejectionCount ? _self.rejectionCount : rejectionCount // ignore: cast_nullable_to_non_nullable
as int,licenseDocUrl: freezed == licenseDocUrl ? _self.licenseDocUrl : licenseDocUrl // ignore: cast_nullable_to_non_nullable
as String?,vehiclePhotoUrl: freezed == vehiclePhotoUrl ? _self.vehiclePhotoUrl : vehiclePhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,licensePlatePhotoUrl: freezed == licensePlatePhotoUrl ? _self.licensePlatePhotoUrl : licensePlatePhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,studentIdDocUrl: freezed == studentIdDocUrl ? _self.studentIdDocUrl : studentIdDocUrl // ignore: cast_nullable_to_non_nullable
as String?,selfieUrl: freezed == selfieUrl ? _self.selfieUrl : selfieUrl // ignore: cast_nullable_to_non_nullable
as String?,faceVerifiedAt: freezed == faceVerifiedAt ? _self.faceVerifiedAt : faceVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [RiderProfile].
extension RiderProfilePatterns on RiderProfile {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RiderProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RiderProfile() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RiderProfile value)  $default,){
final _that = this;
switch (_that) {
case _RiderProfile():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RiderProfile value)?  $default,){
final _that = this;
switch (_that) {
case _RiderProfile() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String vehicleType,  String vehicleMake,  String vehicleModel,  int vehicleYear,  String vehicleColor,  String licensePlate,  String verificationStatus,  String? adminNote,  int rejectionCount,  String? licenseDocUrl,  String? vehiclePhotoUrl,  String? licensePlatePhotoUrl,  String? studentIdDocUrl,  String? selfieUrl,  DateTime? faceVerifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RiderProfile() when $default != null:
return $default(_that.id,_that.vehicleType,_that.vehicleMake,_that.vehicleModel,_that.vehicleYear,_that.vehicleColor,_that.licensePlate,_that.verificationStatus,_that.adminNote,_that.rejectionCount,_that.licenseDocUrl,_that.vehiclePhotoUrl,_that.licensePlatePhotoUrl,_that.studentIdDocUrl,_that.selfieUrl,_that.faceVerifiedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String vehicleType,  String vehicleMake,  String vehicleModel,  int vehicleYear,  String vehicleColor,  String licensePlate,  String verificationStatus,  String? adminNote,  int rejectionCount,  String? licenseDocUrl,  String? vehiclePhotoUrl,  String? licensePlatePhotoUrl,  String? studentIdDocUrl,  String? selfieUrl,  DateTime? faceVerifiedAt)  $default,) {final _that = this;
switch (_that) {
case _RiderProfile():
return $default(_that.id,_that.vehicleType,_that.vehicleMake,_that.vehicleModel,_that.vehicleYear,_that.vehicleColor,_that.licensePlate,_that.verificationStatus,_that.adminNote,_that.rejectionCount,_that.licenseDocUrl,_that.vehiclePhotoUrl,_that.licensePlatePhotoUrl,_that.studentIdDocUrl,_that.selfieUrl,_that.faceVerifiedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String vehicleType,  String vehicleMake,  String vehicleModel,  int vehicleYear,  String vehicleColor,  String licensePlate,  String verificationStatus,  String? adminNote,  int rejectionCount,  String? licenseDocUrl,  String? vehiclePhotoUrl,  String? licensePlatePhotoUrl,  String? studentIdDocUrl,  String? selfieUrl,  DateTime? faceVerifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _RiderProfile() when $default != null:
return $default(_that.id,_that.vehicleType,_that.vehicleMake,_that.vehicleModel,_that.vehicleYear,_that.vehicleColor,_that.licensePlate,_that.verificationStatus,_that.adminNote,_that.rejectionCount,_that.licenseDocUrl,_that.vehiclePhotoUrl,_that.licensePlatePhotoUrl,_that.studentIdDocUrl,_that.selfieUrl,_that.faceVerifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RiderProfile extends RiderProfile {
  const _RiderProfile({required this.id, required this.vehicleType, required this.vehicleMake, required this.vehicleModel, required this.vehicleYear, required this.vehicleColor, required this.licensePlate, required this.verificationStatus, this.adminNote, this.rejectionCount = 0, this.licenseDocUrl, this.vehiclePhotoUrl, this.licensePlatePhotoUrl, this.studentIdDocUrl, this.selfieUrl, this.faceVerifiedAt}): super._();
  factory _RiderProfile.fromJson(Map<String, dynamic> json) => _$RiderProfileFromJson(json);

@override final  String id;
@override final  String vehicleType;
@override final  String vehicleMake;
@override final  String vehicleModel;
@override final  int vehicleYear;
@override final  String vehicleColor;
@override final  String licensePlate;
@override final  String verificationStatus;
// PENDING | APPROVED | REJECTED
@override final  String? adminNote;
/// How many times this application has been rejected. At
/// [AppConstants.maxRiderRejections] the account is blocked outright.
@override@JsonKey() final  int rejectionCount;
// Document URLs, so a resubmission can tell which slots are already filled
// and only re-upload what the applicant actually replaces.
@override final  String? licenseDocUrl;
@override final  String? vehiclePhotoUrl;
@override final  String? licensePlatePhotoUrl;
@override final  String? studentIdDocUrl;
@override final  String? selfieUrl;
/// When the live face check passed. Null on profiles created before face
/// verification existed.
@override final  DateTime? faceVerifiedAt;

/// Create a copy of RiderProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RiderProfileCopyWith<_RiderProfile> get copyWith => __$RiderProfileCopyWithImpl<_RiderProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RiderProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RiderProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.vehicleMake, vehicleMake) || other.vehicleMake == vehicleMake)&&(identical(other.vehicleModel, vehicleModel) || other.vehicleModel == vehicleModel)&&(identical(other.vehicleYear, vehicleYear) || other.vehicleYear == vehicleYear)&&(identical(other.vehicleColor, vehicleColor) || other.vehicleColor == vehicleColor)&&(identical(other.licensePlate, licensePlate) || other.licensePlate == licensePlate)&&(identical(other.verificationStatus, verificationStatus) || other.verificationStatus == verificationStatus)&&(identical(other.adminNote, adminNote) || other.adminNote == adminNote)&&(identical(other.rejectionCount, rejectionCount) || other.rejectionCount == rejectionCount)&&(identical(other.licenseDocUrl, licenseDocUrl) || other.licenseDocUrl == licenseDocUrl)&&(identical(other.vehiclePhotoUrl, vehiclePhotoUrl) || other.vehiclePhotoUrl == vehiclePhotoUrl)&&(identical(other.licensePlatePhotoUrl, licensePlatePhotoUrl) || other.licensePlatePhotoUrl == licensePlatePhotoUrl)&&(identical(other.studentIdDocUrl, studentIdDocUrl) || other.studentIdDocUrl == studentIdDocUrl)&&(identical(other.selfieUrl, selfieUrl) || other.selfieUrl == selfieUrl)&&(identical(other.faceVerifiedAt, faceVerifiedAt) || other.faceVerifiedAt == faceVerifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,vehicleType,vehicleMake,vehicleModel,vehicleYear,vehicleColor,licensePlate,verificationStatus,adminNote,rejectionCount,licenseDocUrl,vehiclePhotoUrl,licensePlatePhotoUrl,studentIdDocUrl,selfieUrl,faceVerifiedAt);

@override
String toString() {
  return 'RiderProfile(id: $id, vehicleType: $vehicleType, vehicleMake: $vehicleMake, vehicleModel: $vehicleModel, vehicleYear: $vehicleYear, vehicleColor: $vehicleColor, licensePlate: $licensePlate, verificationStatus: $verificationStatus, adminNote: $adminNote, rejectionCount: $rejectionCount, licenseDocUrl: $licenseDocUrl, vehiclePhotoUrl: $vehiclePhotoUrl, licensePlatePhotoUrl: $licensePlatePhotoUrl, studentIdDocUrl: $studentIdDocUrl, selfieUrl: $selfieUrl, faceVerifiedAt: $faceVerifiedAt)';
}


}

/// @nodoc
abstract mixin class _$RiderProfileCopyWith<$Res> implements $RiderProfileCopyWith<$Res> {
  factory _$RiderProfileCopyWith(_RiderProfile value, $Res Function(_RiderProfile) _then) = __$RiderProfileCopyWithImpl;
@override @useResult
$Res call({
 String id, String vehicleType, String vehicleMake, String vehicleModel, int vehicleYear, String vehicleColor, String licensePlate, String verificationStatus, String? adminNote, int rejectionCount, String? licenseDocUrl, String? vehiclePhotoUrl, String? licensePlatePhotoUrl, String? studentIdDocUrl, String? selfieUrl, DateTime? faceVerifiedAt
});




}
/// @nodoc
class __$RiderProfileCopyWithImpl<$Res>
    implements _$RiderProfileCopyWith<$Res> {
  __$RiderProfileCopyWithImpl(this._self, this._then);

  final _RiderProfile _self;
  final $Res Function(_RiderProfile) _then;

/// Create a copy of RiderProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? vehicleType = null,Object? vehicleMake = null,Object? vehicleModel = null,Object? vehicleYear = null,Object? vehicleColor = null,Object? licensePlate = null,Object? verificationStatus = null,Object? adminNote = freezed,Object? rejectionCount = null,Object? licenseDocUrl = freezed,Object? vehiclePhotoUrl = freezed,Object? licensePlatePhotoUrl = freezed,Object? studentIdDocUrl = freezed,Object? selfieUrl = freezed,Object? faceVerifiedAt = freezed,}) {
  return _then(_RiderProfile(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as String,vehicleMake: null == vehicleMake ? _self.vehicleMake : vehicleMake // ignore: cast_nullable_to_non_nullable
as String,vehicleModel: null == vehicleModel ? _self.vehicleModel : vehicleModel // ignore: cast_nullable_to_non_nullable
as String,vehicleYear: null == vehicleYear ? _self.vehicleYear : vehicleYear // ignore: cast_nullable_to_non_nullable
as int,vehicleColor: null == vehicleColor ? _self.vehicleColor : vehicleColor // ignore: cast_nullable_to_non_nullable
as String,licensePlate: null == licensePlate ? _self.licensePlate : licensePlate // ignore: cast_nullable_to_non_nullable
as String,verificationStatus: null == verificationStatus ? _self.verificationStatus : verificationStatus // ignore: cast_nullable_to_non_nullable
as String,adminNote: freezed == adminNote ? _self.adminNote : adminNote // ignore: cast_nullable_to_non_nullable
as String?,rejectionCount: null == rejectionCount ? _self.rejectionCount : rejectionCount // ignore: cast_nullable_to_non_nullable
as int,licenseDocUrl: freezed == licenseDocUrl ? _self.licenseDocUrl : licenseDocUrl // ignore: cast_nullable_to_non_nullable
as String?,vehiclePhotoUrl: freezed == vehiclePhotoUrl ? _self.vehiclePhotoUrl : vehiclePhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,licensePlatePhotoUrl: freezed == licensePlatePhotoUrl ? _self.licensePlatePhotoUrl : licensePlatePhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,studentIdDocUrl: freezed == studentIdDocUrl ? _self.studentIdDocUrl : studentIdDocUrl // ignore: cast_nullable_to_non_nullable
as String?,selfieUrl: freezed == selfieUrl ? _self.selfieUrl : selfieUrl // ignore: cast_nullable_to_non_nullable
as String?,faceVerifiedAt: freezed == faceVerifiedAt ? _self.faceVerifiedAt : faceVerifiedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
