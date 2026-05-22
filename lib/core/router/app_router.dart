import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // Auth routes
    GoRoute(path: '/login', builder: (context, state) => const Placeholder()),
    GoRoute(path: '/register', builder: (context, state) => const Placeholder()),
    GoRoute(path: '/otp', builder: (context, state) => const Placeholder()),

    // Main app routes
    GoRoute(path: '/home', builder: (context, state) => const Placeholder()),
    GoRoute(path: '/rides/create', builder: (context, state) => const Placeholder()),
    GoRoute(path: '/rides/active', builder: (context, state) => const Placeholder()),
    GoRoute(path: '/rides/history', builder: (context, state) => const Placeholder()),
    GoRoute(path: '/chat/:rideId', builder: (context, state) => const Placeholder()),
    GoRoute(path: '/notifications', builder: (context, state) => const Placeholder()),
    GoRoute(path: '/profile', builder: (context, state) => const Placeholder()),
    GoRoute(path: '/profile/edit', builder: (context, state) => const Placeholder()),
    GoRoute(path: '/verification', builder: (context, state) => const Placeholder()),
  ],
);
