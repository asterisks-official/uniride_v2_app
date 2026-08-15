import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
    required String role,
    required bool isEmailVerified,

    /// This account was created as a rider application. Distinct from [role],
    /// which is the granted capability — the intent is what holds the account
    /// on the application screen until an admin approves it.
    @Default(false) bool signedUpAsRider,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
