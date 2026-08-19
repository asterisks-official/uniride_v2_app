import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uniride_app/core/di/providers.dart';
import 'package:uniride_app/core/theme/app_theme.dart';
import 'package:uniride_app/features/rides/data/repositories/rides_repository.dart';
import 'package:uniride_app/features/rides/domain/models/ride.dart';
import 'package:uniride_app/features/rides/domain/models/ride_quote.dart';
import 'package:uniride_app/features/rides/presentation/screens/ride_waiting_screen.dart';
import 'package:uniride_app/features/rides/presentation/widgets/trip_map.dart';

import 'support/map_test_support.dart';

// The search pulse animates forever, so these tests pump explicit frames
// rather than pumpAndSettle, which would never settle.

class _FakeRidesRepository implements RidesRepository {
  _FakeRidesRepository(this.ride);

  Ride ride;
  String? cancelled;
  int quoteCalls = 0;

  @override
  Future<Ride> getRide(String rideId) async => ride;

  @override
  Future<void> cancelRide(String rideId, {String? reason}) async {
    cancelled = rideId;
  }

  @override
  Future<RideQuote> quote({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    quoteCalls++;
    return const RideQuote(
      distanceKm: 12.6,
      durationMin: 42,
      total: 239,
      currency: 'BDT',
      polyline: [(23.8069, 90.3668), (23.84, 90.34), (23.8759, 90.3204)],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A freshly posted ride, stamped relative to now.
///
/// Relative rather than a fixed date because the screen counts down against
/// the wall clock: a hardcoded timestamp would make "30 min left" mean
/// something different every day the suite runs.
Ride _ride({
  String type = 'OFFER',
  String mode = 'INSTANT',
  String status = 'SEARCHING',
  int? pending,
  RiderSummary? rider,
  PassengerSummary? passenger,
  bool coordinates = true,
}) {
  final now = DateTime.now();
  return Ride(
    id: 'ride-1',
    type: type,
    mode: mode,
    riderId: null,
    creator: const RiderSummary(
      id: 'u1',
      name: 'Me',
      averageRating: 0,
      ridesCompleted: 0,
    ),
    rider: rider,
    originAddress: 'Mirpur 10',
    destAddress: 'DIU Ashulia',
    originLat: coordinates ? 23.8069 : null,
    originLng: coordinates ? 90.3668 : null,
    destLat: coordinates ? 23.8759 : null,
    destLng: coordinates ? 90.3204 : null,
    // An INSTANT ride departs when it is posted; a scheduled one is for later.
    scheduledAt: mode == 'INSTANT' ? now : now.add(const Duration(hours: 8)),
    createdAt: now,
    fare: 239,
    seatsAvailable: 1,
    status: status,
    genderPref: 'ANY',
    passenger: passenger,
    pendingRequestCount: pending,
  );
}

Widget _host(_FakeRidesRepository rides) => ProviderScope(
  overrides: [ridesRepositoryProvider.overrideWithValue(rides)],
  child: MaterialApp.router(
    theme: AppTheme.light,
    routerConfig: GoRouter(
      initialLocation: '/rides/ride-1/waiting',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/rides/create',
          builder: (_, _) => const Scaffold(body: Text('compose')),
        ),
        GoRoute(
          path: '/rides/:id',
          builder: (_, state) =>
              Scaffold(body: Text('detail ${state.pathParameters['id']}')),
          routes: [
            GoRoute(
              path: 'waiting',
              builder: (_, state) =>
                  RideWaitingScreen(rideId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: 'requests',
              builder: (_, _) => const Scaffold(body: Text('requests')),
            ),
          ],
        ),
      ],
    ),
  ),
);

Future<void> _pumpLoaded(
  WidgetTester tester,
  _FakeRidesRepository rides,
) async {
  ignoreTileFetchErrors();
  // A phone-shaped surface, not the 800x600 default: the body is a ListView,
  // so anything below the fold is never built and `find.text` cannot see it.
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_host(rides));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('a searching offer shows the waiting state with cancel', (
    tester,
  ) async {
    final rides = _FakeRidesRepository(_ride());
    await _pumpLoaded(tester, rides);

    expect(find.text('Your ride is live'), findsOneWidget);
    expect(find.text('Mirpur 10'), findsOneWidget);
    expect(find.text('DIU Ashulia'), findsOneWidget);
    expect(find.text('Cancel ride'), findsOneWidget);
  });

  testWidgets('a searching request reads passenger-side', (tester) async {
    final rides = _FakeRidesRepository(_ride(type: 'REQUEST'));
    await _pumpLoaded(tester, rides);

    expect(find.text('Finding you a rider'), findsOneWidget);
    expect(find.text('Cancel request'), findsOneWidget);
  });

  testWidgets('cancel confirms, calls the API and leaves', (tester) async {
    final rides = _FakeRidesRepository(_ride());
    await _pumpLoaded(tester, rides);

    await tester.tap(find.text('Cancel ride'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Cancel this ride?'), findsOneWidget);

    await tester.tap(find.text('Yes, cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(rides.cancelled, 'ride-1');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('keeping the dialog does not cancel', (tester) async {
    final rides = _FakeRidesRepository(_ride());
    await _pumpLoaded(tester, rides);

    await tester.tap(find.text('Cancel ride'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Keep it'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(rides.cancelled, isNull);
    expect(find.text('Your ride is live'), findsOneWidget);
  });

  testWidgets('pending join requests surface a way into them', (tester) async {
    final rides = _FakeRidesRepository(_ride(pending: 2));
    await _pumpLoaded(tester, rides);

    expect(find.text('2 passengers asked to join'), findsOneWidget);

    await tester.tap(find.text('2 passengers asked to join'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('requests'), findsOneWidget);
  });

  testWidgets('the trip is drawn on a map above the status', (tester) async {
    final rides = _FakeRidesRepository(_ride());
    await _pumpLoaded(tester, rides);

    // Map on top, status below — and the route came from the quote the
    // compose screen had already asked for.
    final map = tester.widget<TripMap>(find.byType(TripMap));
    expect(map.route, hasLength(3));
    expect(rides.quoteCalls, 1);

    // The light only runs while the ride is still open to takers.
    expect(map.pulse, isTrue);
    expect(find.text('Your ride is live'), findsOneWidget);
  });

  testWidgets('the route stops pulsing once the ride is matched', (
    tester,
  ) async {
    final rides = _FakeRidesRepository(_ride(status: 'MATCHED'));
    await _pumpLoaded(tester, rides);

    expect(tester.widget<TripMap>(find.byType(TripMap)).pulse, isFalse);
  });

  testWidgets('a ride with no coordinates skips the map entirely', (
    tester,
  ) async {
    // Rides posted by v1 clients were stored at (0,0). Framing a map on them
    // would put the trip in the Gulf of Guinea.
    final rides = _FakeRidesRepository(_ride(coordinates: false));
    await _pumpLoaded(tester, rides);

    expect(find.byType(TripMap), findsNothing);
    expect(rides.quoteCalls, 0);
    expect(find.text('Your ride is live'), findsOneWidget);
    expect(find.text('Cancel ride'), findsOneWidget);
  });

  testWidgets('an instant post counts down its search window', (tester) async {
    final rides = _FakeRidesRepository(_ride());
    await _pumpLoaded(tester, rides);

    // Posted "now" against a 30-minute window, so the deadline is in sight
    // from the first frame rather than only once it is nearly up.
    expect(find.text('Posted just now'), findsOneWidget);
    expect(find.text('30 min left'), findsOneWidget);
  });

  testWidgets('a scheduled post shows no countdown', (tester) async {
    // The window is the wait until departure — days, sometimes. An arc over
    // that would sit still and say nothing.
    final rides = _FakeRidesRepository(_ride(mode: 'SCHEDULED'));
    await _pumpLoaded(tester, rides);

    expect(find.text('Posted just now'), findsOneWidget);
    expect(find.textContaining('min left'), findsNothing);
  });

  testWidgets('an expired offer says nobody joined, not "completed"', (
    tester,
  ) async {
    // The backend expires a still-SEARCHING ride; the screen must say so
    // rather than fall through to a completion message for a trip that
    // never happened.
    final rides = _FakeRidesRepository(_ride(status: 'EXPIRED'));
    await _pumpLoaded(tester, rides);

    expect(find.text('No one joined this time'), findsOneWidget);
    expect(find.text('Ride completed'), findsNothing);

    await tester.tap(find.text('Post again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('compose'), findsOneWidget);
  });

  testWidgets('an expired request says no rider was found', (tester) async {
    final rides = _FakeRidesRepository(
      _ride(type: 'REQUEST', status: 'EXPIRED'),
    );
    await _pumpLoaded(tester, rides);

    expect(find.text('No rider found'), findsOneWidget);
  });

  testWidgets('a matched ride flips to the resolved state', (tester) async {
    final rides = _FakeRidesRepository(
      _ride(
        status: 'MATCHED',
        passenger: const PassengerSummary(id: 'p9', name: 'Nadia'),
      ),
    );
    await _pumpLoaded(tester, rides);

    expect(find.text("You're matched!"), findsOneWidget);
    expect(find.textContaining('Nadia'), findsOneWidget);

    await tester.tap(find.text('View ride'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('detail ride-1'), findsOneWidget);
  });
}
