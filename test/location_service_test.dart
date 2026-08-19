import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/core/services/location_service.dart';

/// The copy is the product here.
///
/// A permission refusal is the most common outcome this service has, and what
/// the user is told at that moment decides whether they find the way round it
/// or give up on the feature. These assert the two things that must hold: the
/// message always offers a way forward, and only a permanent denial sends
/// someone to Settings — suggesting it for a one-off "not now" would be wrong
/// advice, since asking again works fine.
void main() {
  group('denial messages', () {
    test('every reason offers something the user can actually do', () {
      for (final reason in LocationFailure.values) {
        final message = LocationDenied(reason).message;
        expect(message, isNotEmpty, reason: reason.name);
        // Never a bare "location unavailable" — there is always another route
        // to a pickup point.
        expect(
          message.toLowerCase(),
          anyOf(contains('pin'), contains('settings'), contains('try again')),
          reason: reason.name,
        );
      }
    });

    test('only a permanent denial points at Settings', () {
      expect(
        const LocationDenied(LocationFailure.deniedForever).needsSettings,
        isTrue,
      );
      // The system will ask again after a soft denial, so sending someone to
      // Settings would be busywork.
      expect(
        const LocationDenied(LocationFailure.denied).needsSettings,
        isFalse,
      );
      expect(
        const LocationDenied(LocationFailure.serviceDisabled).needsSettings,
        isFalse,
      );
      expect(
        const LocationDenied(LocationFailure.timeout).needsSettings,
        isFalse,
      );
    });

    test('a disabled device switch is not blamed on the app', () {
      // Different remedy from a denied permission, so it must not share copy.
      final disabled =
          const LocationDenied(LocationFailure.serviceDisabled).message;
      final denied = const LocationDenied(LocationFailure.denied).message;
      expect(disabled, isNot(denied));
      expect(disabled.toLowerCase(), contains('your phone'));
    });
  });

  group('results', () {
    test('a found position carries its coordinates', () {
      const found = LocationFound(23.8069, 90.3668);
      expect(found.lat, 23.8069);
      expect(found.lng, 90.3668);
    });

    test('the two outcomes are distinguishable by type', () {
      // Callers switch on this, and an unhandled case must be a compile error
      // rather than a silent fall-through.
      const LocationResult result = LocationFound(23.8, 90.36);
      final described = switch (result) {
        LocationFound() => 'found',
        LocationDenied() => 'denied',
      };
      expect(described, 'found');
    });
  });
}
