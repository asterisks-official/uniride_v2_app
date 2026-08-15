import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/core/router/app_router.dart';
import 'package:uniride_app/features/auth/domain/models/user.dart';
import 'package:uniride_app/features/auth/presentation/providers/auth_notifier.dart';

const _user = User(
  id: 'u1',
  name: 'Shakib Ahmed',
  email: 'shakib@diu.edu.bd',
  role: 'PASSENGER',
  isEmailVerified: true,
);

/// Signed up as a rider, application not approved.
const _lockedRider = Authenticated(_user, riderGate: RiderGate.locked);

/// Signed up as a rider, status not yet fetched.
const _checkingRider = Authenticated(_user, riderGate: RiderGate.checking);

const _passenger = Authenticated(_user);

/// Everywhere in the app that is not the rider application.
const _elsewhere = [
  '/home',
  '/alerts',
  '/profile',
  '/rides',
  '/rides/create',
  '/otp',
  '/splash',
];

void main() {
  group('rider signup', () {
    test('cannot reach any part of the app but the application', () {
      for (final route in _elsewhere) {
        expect(
          authRedirect(_lockedRider, route, onboardingSeen: true),
          '/verification',
          reason: '$route should be closed to an unapproved rider',
        );
      }
    });

    test('is left on the application once there', () {
      expect(
        authRedirect(_lockedRider, '/verification', onboardingSeen: true),
        isNull,
      );
    });

    test('waits on the splash while the status is being fetched', () {
      // Rather than flashing the feed for the frame before the answer lands.
      expect(
        authRedirect(_checkingRider, '/home', onboardingSeen: true),
        '/splash',
      );
      expect(
        authRedirect(_checkingRider, '/verification', onboardingSeen: true),
        '/splash',
      );
      expect(
        authRedirect(_checkingRider, '/splash', onboardingSeen: true),
        isNull,
      );
    });

    test('is let through once the gate opens', () {
      const approved = Authenticated(_user);
      expect(authRedirect(approved, '/home', onboardingSeen: true), isNull);
      expect(authRedirect(approved, '/splash', onboardingSeen: true), '/home');
    });
  });

  group('passenger', () {
    test('lands on the feed after verifying', () {
      expect(authRedirect(_passenger, '/otp', onboardingSeen: true), '/home');
      expect(
        authRedirect(_passenger, '/splash', onboardingSeen: true),
        '/home',
      );
    });

    test('moves around freely', () {
      for (final route in ['/home', '/alerts', '/profile', '/rides/create']) {
        expect(authRedirect(_passenger, route, onboardingSeen: true), isNull);
      }
    });

    test('can still open the rider application voluntarily', () {
      expect(
        authRedirect(_passenger, '/verification', onboardingSeen: true),
        isNull,
      );
    });
  });

  group('session', () {
    test('signed-out users are sent to login', () {
      expect(
        authRedirect(
          const Unauthenticated(),
          '/verification',
          onboardingSeen: true,
        ),
        '/login',
      );
      expect(
        authRedirect(const Unauthenticated(), '/home', onboardingSeen: true),
        '/login',
      );
    });

    test('signed-out users may stay on the auth screens', () {
      for (final route in [
        '/login',
        '/register',
        '/otp',
        '/forgot-password',
        '/reset-password',
      ]) {
        expect(
          authRedirect(const Unauthenticated(), route, onboardingSeen: true),
          isNull,
        );
      }
    });

    test('an unresolved session waits on the splash', () {
      expect(
        authRedirect(const AuthUnknown(), '/home', onboardingSeen: true),
        '/splash',
      );
      expect(
        authRedirect(const AuthUnknown(), '/splash', onboardingSeen: true),
        isNull,
      );
    });
  });

  group('onboarding', () {
    test('a first-run visitor sees it before anything else', () {
      for (final route in ['/splash', '/login', '/register', '/home']) {
        expect(
          authRedirect(const Unauthenticated(), route, onboardingSeen: false),
          '/onboarding',
        );
      }
    });

    test('it is left alone once there', () {
      expect(
        authRedirect(
          const Unauthenticated(),
          '/onboarding',
          onboardingSeen: false,
        ),
        isNull,
      );
    });

    test('finishing it hands over to login', () {
      expect(
        authRedirect(
          const Unauthenticated(),
          '/onboarding',
          onboardingSeen: true,
        ),
        '/login',
      );
    });

    test('a signed-in user is never shown it', () {
      // On an existing install the flag is false only because it postdates
      // them; interrupting a working session to introduce the app is worse
      // than skipping it.
      expect(authRedirect(_passenger, '/home', onboardingSeen: false), isNull);
      expect(
        authRedirect(_passenger, '/onboarding', onboardingSeen: false),
        '/home',
      );
    });

    test('it does not become a way around the rider gate', () {
      expect(
        authRedirect(_lockedRider, '/onboarding', onboardingSeen: false),
        '/verification',
      );
    });

    test('an unresolved session still waits on the splash', () {
      // Onboarding must not pre-empt the session check, or a returning user
      // gets introduced to the app they are already logged into.
      expect(
        authRedirect(const AuthUnknown(), '/home', onboardingSeen: false),
        '/splash',
      );
    });
  });
}
