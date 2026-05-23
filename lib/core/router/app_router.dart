import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/rider/presentation/screens/rider_verification_screen.dart';
import '../../shared/screens/splash_screen.dart';

const _authRoutes = {
  '/login',
  '/register',
  '/otp',
  '/forgot-password',
  '/reset-password',
};

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod auth state changes into a Listenable GoRouter can refresh on.
  final refresh = ValueNotifier(0);
  ref.listen(authNotifierProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      if (auth is AuthUnknown) {
        return loc == '/splash' ? null : '/splash';
      }

      final loggedIn = auth is Authenticated;
      if (!loggedIn) {
        if (_authRoutes.contains(loc)) return null;
        return '/login';
      }

      // Authenticated: keep the user out of splash/auth screens.
      if (loc == '/splash' || _authRoutes.contains(loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const AuthScreen(initialTab: 0)),
      GoRoute(
        path: '/register',
        builder: (_, _) => const AuthScreen(initialTab: 1),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpScreen(
            email: extra?['email'] as String?,
            devOtp: extra?['devOtp'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ResetPasswordScreen(
            email: extra?['email'] as String? ?? '',
            devOtp: extra?['devOtp'] as String?,
          );
        },
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '/verification',
        builder: (_, _) => const RiderVerificationScreen(),
      ),
    ],
  );
});
