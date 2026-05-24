import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/onboarding_provider.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/notifications/presentation/screens/alerts_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authNotifierProvider, (_, _) => refresh.value++);
  ref.listen(onboardingSeenProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      // Wait for session restore.
      if (auth is AuthUnknown) {
        return loc == '/splash' ? null : '/splash';
      }

      // Show onboarding on first install before anything else.
      final onboardingSeen = ref.read(onboardingSeenProvider);
      if (!onboardingSeen) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      final loggedIn = auth is Authenticated;
      if (!loggedIn) {
        if (_authRoutes.contains(loc)) return null;
        return '/login';
      }

      // Authenticated: redirect away from splash/auth/onboarding.
      if (loc == '/splash' || loc == '/onboarding' || _authRoutes.contains(loc)) {
        return '/home';
      }
      return null;
    },
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
        builder: (_, state) => RideDetailScreen(
          rideId: state.pathParameters['id']!,
        ),
        routes: [
          GoRoute(
            path: 'requests',
            builder: (_, state) => RideRequestsScreen(
              rideId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      // My Rides as a full-screen push destination (accessible from Profile)
      GoRoute(
        path: '/rides',
        builder: (_, _) => const MyRidesScreen(),
      ),

      // Authenticated shell with bottom nav (Home | Create | Alerts | Profile)
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/alerts',
                builder: (_, _) => const AlertsScreen(),
              ),
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
