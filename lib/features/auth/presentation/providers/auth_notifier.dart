import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/user.dart';

sealed class AuthState {
  const AuthState();
}

/// Session restoration in progress (app just launched).
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class Authenticated extends AuthState {
  const Authenticated(this.user);
  final User user;
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
    state = user != null ? Authenticated(user) : const Unauthenticated();
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
    state = Authenticated(user);
  }

  /// Throws [AppException] on failure; sets [Authenticated] on success.
  Future<void> verifyEmail(String otp) async {
    final user = await _repo.verifyEmail(otp);
    state = Authenticated(user);
  }

  /// Returns the dev OTP when the backend runs in non-production mode.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    String? university,
    String? phone,
  }) {
    return _repo.register(
      name: name,
      email: email,
      password: password,
      university: university,
      phone: phone,
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
    await _repo.logout();
    state = const Unauthenticated();
  }

  /// Refreshes the token + user so a server-side role change (e.g. rider
  /// approval) takes effect in the current session.
  Future<void> refreshSession() async {
    final user = await _repo.refreshSession();
    state = Authenticated(user);
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
