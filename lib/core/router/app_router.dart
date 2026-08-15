import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/onboarding_provider.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/notifications/presentation/screens/alerts_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/rider/presentation/screens/rider_verification_screen.dart';
import '../../features/rides/presentation/screens/create_ride_screen.dart';
import '../../features/rides/presentation/screens/my_rides_screen.dart';
import '../../features/rides/presentation/screens/ride_detail_screen.dart';
import '../../features/rides/presentation/screens/ride_requests_screen.dart';
import '../../shared/screens/app_shell.dart';
import '../../shared/screens/splash_screen.dart';

const _authRoutes = {
  '/login',
  '/register',
  '/otp',
  '/forgot-password',
  '/reset-password',
};

/// Where [auth] belongs when it asks for [location]. Null allows the location
/// as-is.
///
/// Kept as a plain function so the rule can be exercised without a widget tree
/// — the rider redirect below is the sort of thing that breaks silently.
String? authRedirect(
  AuthState auth,
  String location, {
  required bool onboardingSeen,
}) {
  if (auth is AuthUnknown) {
    return location == '/splash' ? null : '/splash';
  }

  if (auth is! Authenticated) {
    // First run: say what the app is for before asking anyone to sign up.
    // Only for signed-out users — someone with a session has plainly already
    // been introduced, and on an existing install the flag is false purely
    // because it postdates them.
    if (!onboardingSeen) {
      return location == '/onboarding' ? null : '/onboarding';
    }
    if (location == '/onboarding') return '/login';
    if (_authRoutes.contains(location)) return null;
    return '/login';
  }

  switch (auth.riderGate) {
    // Still asking the server. Wait on the splash rather than show a feed the
    // next frame may take away.
    case RiderGate.checking:
      return location == '/splash' ? null : '/splash';

    // Signed up as a rider without an approved application: the application is
    // the only screen they get. Enforced here rather than by hiding buttons,
    // so it survives deep links and a restart mid-flow.
    case RiderGate.locked:
      return location == '/verification' ? null : '/verification';

    case RiderGate.open:
      break;
  }

  // Authenticated: keep out of splash/onboarding/auth screens.
  if (location == '/splash' ||
      location == '/onboarding' ||
      _authRoutes.contains(location)) {
    return '/home';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authNotifierProvider, (_, _) => refresh.value++);
  ref.listen(onboardingSeenProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      ref.read(authNotifierProvider),
      state.matchedLocation,
      onboardingSeen: ref.read(onboardingSeenProvider),
    ),
    routes: [
      // Public / auth routes (outside the shell — no bottom nav)
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/login',
        builder: (_, _) => const AuthScreen(initialTab: 0),
      ),
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

      // Full-screen authenticated routes (no bottom nav)
      GoRoute(
        path: '/verification',
        builder: (_, _) => const RiderVerificationScreen(),
      ),
      // /rides/create must come before /rides/:id to avoid being captured as id='create'
      GoRoute(
        path: '/rides/create',
        builder: (_, _) => const CreateRideScreen(),
      ),
      GoRoute(
        path: '/rides/:id',
        builder: (_, state) =>
            RideDetailScreen(rideId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'requests',
            builder: (_, state) =>
                RideRequestsScreen(rideId: state.pathParameters['id']!),
          ),
        ],
      ),
      // My Rides as a full-screen push destination (accessible from Profile)
      GoRoute(path: '/rides', builder: (_, _) => const MyRidesScreen()),

      // Authenticated shell with bottom nav (Home | Create | Alerts | Profile)
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
