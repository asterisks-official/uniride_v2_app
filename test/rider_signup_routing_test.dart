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
          authRedirect(_lockedRider, route),
          '/verification',
          reason: '$route should be closed to an unapproved rider',
        );
      }
    });

    test('is left on the application once there', () {
      expect(authRedirect(_lockedRider, '/verification'), isNull);
    });

    test('waits on the splash while the status is being fetched', () {
      // Rather than flashing the feed for the frame before the answer lands.
      expect(authRedirect(_checkingRider, '/home'), '/splash');
      expect(authRedirect(_checkingRider, '/verification'), '/splash');
      expect(authRedirect(_checkingRider, '/splash'), isNull);
    });

    test('is let through once the gate opens', () {
      const approved = Authenticated(_user);
      expect(authRedirect(approved, '/home'), isNull);
      expect(authRedirect(approved, '/splash'), '/home');
    });
  });

  group('passenger', () {
    test('lands on the feed after verifying', () {
      expect(authRedirect(_passenger, '/otp'), '/home');
      expect(authRedirect(_passenger, '/splash'), '/home');
    });

    test('moves around freely', () {
      for (final route in ['/home', '/alerts', '/profile', '/rides/create']) {
        expect(authRedirect(_passenger, route), isNull);
      }
    });

    test('can still open the rider application voluntarily', () {
      expect(authRedirect(_passenger, '/verification'), isNull);
    });
  });

  group('session', () {
    test('signed-out users are sent to login', () {
      expect(authRedirect(const Unauthenticated(), '/verification'), '/login');
      expect(authRedirect(const Unauthenticated(), '/home'), '/login');
    });

    test('signed-out users may stay on the auth screens', () {
      for (final route in [
        '/login',
        '/register',
        '/otp',
        '/forgot-password',
        '/reset-password',
      ]) {
        expect(authRedirect(const Unauthenticated(), route), isNull);
      }
    });

    test('an unresolved session waits on the splash', () {
      expect(authRedirect(const AuthUnknown(), '/home'), '/splash');
      expect(authRedirect(const AuthUnknown(), '/splash'), isNull);
    });
  });
}
