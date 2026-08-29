import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/account_enums.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/providers/gender_provider.dart';
import '../../../../core/push/push_service.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/user.dart';

sealed class AuthState {
  const AuthState();
}

/// Session restoration in progress (app just launched).
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// Whether an account that signed up as a rider may use the rest of the app.
enum RiderGate {
  /// Not a rider signup, or the application has been decided.
  open,

  /// The application's status is still being fetched.
  checking,

  /// Signed up as a rider with no approved application — held on the
  /// application screen.
  locked,
}

/// Whether [user]'s application status has to be fetched before the app opens
/// to them.
///
/// A granted RIDER role is proof of approval on its own, so approved riders
/// never pay for this check — which also means they are not locked out by a
/// launch with no connection.
bool riderGateNeedsCheck(User user) =>
    user.signedUpAsRider && user.role != 'RIDER';

/// The gate implied by an application's status. Null means no application yet.
RiderGate riderGateForStatus(String? verificationStatus) =>
    switch (verificationStatus) {
      'APPROVED' => RiderGate.open,
      // Not applied, still PENDING, or rejected. A rejection is not a way out:
      // it comes with a reason and another attempt. Nobody is stranded by this
      // — an applicant who runs out of attempts is blocked at the account
      // level and never reaches a session at all.
      _ => RiderGate.locked,
    };

class Authenticated extends AuthState {
  const Authenticated(this.user, {this.riderGate = RiderGate.open});

  final User user;

  /// Re-derived from the server on every launch, sign-in and refresh — a
  /// device-local flag would be a reinstall away from being bypassed.
  final RiderGate riderGate;
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    _bootstrap();
    return const AuthUnknown();
  }

  Future<void> _bootstrap() async {
    final user = await _repo.tryRestoreSession();
    // Registering stores a short-lived token before the email is verified, so a
    // cold start in that window can restore a half-made account. Refusing it
    // here is what stops an unverified signup walking into the app.
    if (user == null || !user.isEmailVerified) {
      state = const Unauthenticated();
      return;
    }
    await _authenticate(user);
  }

  /// Publishes the session, then settles the rider gate.
  ///
  /// Two states rather than one because deciding needs a network round-trip:
  /// the router holds on the splash while it is [RiderGate.checking] rather
  /// than flashing the feed at someone who is about to be sent back out of it.
  Future<void> _authenticate(User user) async {
    final needsCheck = riderGateNeedsCheck(user);
    state = Authenticated(
      user,
      riderGate: needsCheck ? RiderGate.checking : RiderGate.open,
    );

    // Deliberately not awaited: registering for push must not delay the first
    // authenticated frame, and it is allowed to fail. Every path into a signed
    // in state lands here — login, registration, and a restored session — so
    // this is the one place it needs to happen.
    unawaited(_registerForPush());

    if (!needsCheck) return;

    final gate = await _riderGateFor(user);
    final current = state;
    // A logout or session change mid-flight wins over a stale answer.
    if (current is Authenticated && current.user.id == user.id) {
      state = Authenticated(user, riderGate: gate);
    }
  }

  /// Hands the backend this install's FCM token, and keeps doing so when FCM
  /// rotates it. Without the refresh listener a long-lived session goes quiet
  /// at the first rotation with nothing to show for it.
  Future<void> _registerForPush() async {
    final token = await PushService.token();
    if (token == null) return;

    final repo = _repo;
    await repo.registerDevice(
      fcmToken: token,
      deviceType: PushService.deviceType,
    );
    PushService.onTokenRefresh((refreshed) {
      // Only while still signed in — a token registered after logout would
      // deliver another user's notifications to this device.
      if (state is! Authenticated) return;
      repo.registerDevice(
        fcmToken: refreshed,
        deviceType: PushService.deviceType,
      );
    });
  }

  Future<RiderGate> _riderGateFor(User user) async {
    try {
      final profile = await ref.read(riderRepositoryProvider).getProfile();
      return riderGateForStatus(profile?.verificationStatus);
    } on AppException {
      // Status unconfirmed — hold them at the application screen, which shows
      // the error with a retry, rather than letting an offline launch through.
      return RiderGate.locked;
    }
  }

  /// Re-checks the application status against the server. Called from the
  /// "under review" screen so approval takes effect without a restart.
  Future<void> recheckRiderGate() async {
    final current = state;
    if (current is! Authenticated) return;
    await _authenticate(current.user);
  }

  /// Throws [AppException] on failure; sets [Authenticated] on success.
  Future<void> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final user = await _repo.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
    await _authenticate(user);
  }

  /// Throws [AppException] on failure; sets [Authenticated] on success.
  Future<void> verifyEmail(String otp) async {
    final user = await _repo.verifyEmail(otp);
    await _authenticate(user);
  }

  /// Returns the dev OTP when the backend runs in non-production mode.
  Future<RegisterResult> register({
    required String name,
    required String email,
    required String password,
    required Gender gender,
    required String studentIdNumber,
    required JoinAs joinAs,
    String? university,
    String? phone,
  }) {
    return _repo.register(
      name: name,
      email: email,
      password: password,
      gender: gender,
      studentIdNumber: studentIdNumber,
      joinAs: joinAs,
      university: university,
      phone: phone,
    );
  }

  /// Switch sides. Callers must invalidate cached feeds afterwards — the new
  /// tokens serve the opposite side of the market, so anything already fetched
  /// is for the wrong audience.
  Future<ActiveMode> switchMode(ActiveMode mode) => _repo.switchMode(mode);

  Future<void> completeProfile({
    required Gender gender,
    required String studentIdNumber,
  }) {
    return _repo.completeProfile(
      gender: gender,
      studentIdNumber: studentIdNumber,
    );
  }

  Future<String?> forgotPassword(String email) => _repo.forgotPassword(email);

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return _repo.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }

  Future<void> logout() async {
    // Stop first: a rotation arriving mid-logout would re-register this device
    // against the account that is on its way out.
    await PushService.stopListening();
    await _repo.logout();
    // The next account on this device must not inherit the previous user's
    // gender, which decides what the compose screen offers.
    ref.read(cachedGenderProvider.notifier).clear();
    state = const Unauthenticated();
  }

  /// Refreshes the token + user so a server-side role change (e.g. rider
  /// approval) takes effect in the current session.
  Future<void> refreshSession() async {
    final user = await _repo.refreshSession();
    await _authenticate(user);
  }

  User? get currentUser {
    final s = state;
    return s is Authenticated ? s.user : null;
  }

  void onSessionExpired() => state = const Unauthenticated();
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
