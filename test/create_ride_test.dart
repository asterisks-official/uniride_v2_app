import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:uniride_app/core/constants/account_enums.dart';
import 'package:uniride_app/core/di/providers.dart';
import 'package:uniride_app/core/providers/gender_provider.dart';
import 'package:uniride_app/core/theme/app_theme.dart';
import 'package:uniride_app/features/places/data/repositories/geocoding_repository.dart';
import 'package:uniride_app/features/places/data/repositories/places_repository.dart';
import 'package:uniride_app/features/places/domain/models/place_suggestion.dart';
import 'package:uniride_app/features/places/domain/models/saved_place.dart';
import 'package:uniride_app/features/profile/domain/models/user_profile.dart';
import 'package:uniride_app/features/profile/presentation/providers/profile_notifier.dart';
import 'package:uniride_app/features/rides/data/repositories/rides_repository.dart';
import 'package:uniride_app/features/rides/domain/models/ride_quote.dart';
import 'package:uniride_app/features/rides/presentation/screens/create_ride_screen.dart';
import 'package:uniride_app/features/rides/presentation/widgets/compose_widgets.dart';
import 'package:uniride_app/shared/exceptions/app_exception.dart';

import 'support/map_test_support.dart';

class _FakePlacesRepository implements PlacesRepository {
  _FakePlacesRepository(this.places);

  final List<SavedPlace> places;

  @override
  Future<List<SavedPlace>> list() async => places;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeGeocodingRepository implements GeocodingRepository {
  @override
  Future<List<PlaceSuggestion>> search(String query) async => const [];

  @override
  Future<PickedPlace?> resolve(PlaceSuggestion suggestion) async => null;

  @override
  Future<String> reverse(double lat, double lng) async => 'Somewhere';
}

class _FakeRidesRepository implements RidesRepository {
  _FakeRidesRepository({this.quoteFails = false});

  final bool quoteFails;
  int quoteCalls = 0;
  Map<String, dynamic>? created;

  @override
  Future<RideQuote> quote({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    quoteCalls++;
    if (quoteFails) throw const NetworkException('offline');
    return const RideQuote(
      distanceKm: 12.6,
      durationMin: 42,
      total: 239,
      currency: 'BDT',
    );
  }

  @override
  Future<String> createTrip({
    required String type,
    required String mode,
    required PickedPlace pickup,
    required PickedPlace destination,
    String? scheduledAt,
    String genderPref = 'ANY',
  }) async {
    created = {
      'type': type,
      'mode': mode,
      'genderPref': genderPref,
      'scheduledAt': scheduledAt,
      'from': pickup.displayName,
      'to': destination.displayName,
    };
    return 'ride-1';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier(this._profile);

  final UserProfile _profile;

  @override
  Future<UserProfile> build() async => _profile;
}

UserProfile _profileIn(
  ActiveMode mode, {
  String role = 'RIDER',
  Gender? gender = Gender.male,
}) => UserProfile(
  id: 'u1',
  name: 'Test Student',
  email: 't@diu.edu.bd',
  role: role,
  isEmailVerified: true,
  activeMode: mode,
  gender: gender,
  studentIdNumber: '221-15-1000',
);

const _home = SavedPlace(
  id: 'p1',
  label: 'Home',
  lat: 23.8069,
  lng: 90.3668,
  areaLabel: 'Mirpur 10',
);
const _campus = SavedPlace(
  id: 'p2',
  label: 'Campus',
  lat: 23.8759,
  lng: 90.3204,
  areaLabel: 'Ashulia',
);

Widget _host({
  required ActiveMode mode,
  String role = 'RIDER',
  Gender? gender = Gender.male,
  List<SavedPlace> places = const [_home, _campus],
  _FakeRidesRepository? rides,
}) {
  return ProviderScope(
    overrides: [
      placesRepositoryProvider.overrideWithValue(_FakePlacesRepository(places)),
      geocodingRepositoryProvider.overrideWithValue(_FakeGeocodingRepository()),
      ridesRepositoryProvider.overrideWithValue(
        rides ?? _FakeRidesRepository(),
      ),
      profileNotifierProvider.overrideWith(
        () =>
            _FakeProfileNotifier(_profileIn(mode, role: role, gender: gender)),
      ),
      cachedGenderProvider.overrideWith(() => CachedGenderNotifier(gender)),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const CreateRideScreen()),
          GoRoute(
            path: '/rides/:id',
            builder: (_, state) =>
                Scaffold(body: Text('ride ${state.pathParameters['id']}')),
            routes: [
              GoRoute(
                path: 'waiting',
                builder: (_, state) => Scaffold(
                  body: Text('waiting ${state.pathParameters['id']}'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

void _tallPhone(WidgetTester tester) {
  ignoreTileFetchErrors();
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _scrollDown(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -500));
  await tester.pumpAndSettle();
}

/// Sets the destination through the real picker, choosing a saved place —
/// which is the path a user actually takes.
Future<void> _setDestination(WidgetTester tester) async {
  await tester.tap(find.text('Where to?'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Campus'));
  await tester.pumpAndSettle();
}

/// Opens the when-sheet and picks the first scheduled slot.
Future<void> _schedule(WidgetTester tester) async {
  await tester.tap(find.text('Now'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(ComposeChip).first);
  await tester.pumpAndSettle();
}

void main() {
  group('mode', () {
    testWidgets('defaults to Now, and Now hides the schedule fields', (
      tester,
    ) async {
      _tallPhone(tester);
      await tester.pumpWidget(_host(mode: ActiveMode.passenger));
      await tester.pumpAndSettle();

      expect(find.text('Find me a rider'), findsOneWidget);
      // The when-control reads "Now" rather than a date.
      expect(find.text('Now'), findsOneWidget);
    });

    testWidgets('the when-sheet offers now or a time', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(_host(mode: ActiveMode.passenger));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Now'));
      await tester.pumpAndSettle();

      expect(find.text('When are you leaving?'), findsOneWidget);
      expect(find.text('Pick an exact time'), findsOneWidget);
    });

    testWidgets('picking a slot switches the trip to scheduled', (
      tester,
    ) async {
      _tallPhone(tester);
      await tester.pumpWidget(_host(mode: ActiveMode.passenger));
      await tester.pumpAndSettle();
      await _schedule(tester);

      expect(find.text('Post my request'), findsOneWidget);
      // The button now reports the chosen time rather than "Now".
      expect(find.text('Now'), findsNothing);
    });

    testWidgets('rider mode offers, with no choice to make', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(_host(mode: ActiveMode.rider));
      await tester.pumpAndSettle();

      // The side is the role. Offering is not buried behind Schedule either —
      // a rider leaving this minute can post it.
      expect(find.text('Offer this ride now'), findsOneWidget);
    });

    testWidgets('passenger mode asks, with no choice to make', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(_host(mode: ActiveMode.passenger));
      await tester.pumpAndSettle();

      expect(find.text('Find me a rider'), findsOneWidget);
    });

    testWidgets('the screen never offers to pick a side', (tester) async {
      // Switching sides is the profile's mode control. A second one here
      // would be two ways to say the same thing, and they could disagree.
      for (final mode in ActiveMode.values) {
        _tallPhone(tester);
        await tester.pumpWidget(_host(mode: mode));
        await tester.pumpAndSettle();

        // No segmented control at all for a male user: gender is the only one
        // on this screen and only women see it.
        expect(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString().startsWith('ComposeSegmented'),
          ),
          findsNothing,
          reason: mode.name,
        );
      }
    });
  });

  group('route', () {
    testWidgets('pickup is pre-filled, destination is not', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(_host(mode: ActiveMode.passenger));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Where to?'), findsOneWidget);
    });

    testWidgets('no fare, and no request spent, until both ends are set', (
      tester,
    ) async {
      _tallPhone(tester);
      final rides = _FakeRidesRepository();
      await tester.pumpWidget(_host(mode: ActiveMode.passenger, rides: rides));
      await tester.pumpAndSettle();

      expect(
        find.text('Set both ends to see the route and the fare.'),
        findsOneWidget,
      );
      expect(rides.quoteCalls, 0);

      await _setDestination(tester);
      expect(find.text('৳239'), findsOneWidget);
      expect(rides.quoteCalls, 1);
    });

    testWidgets('swap exchanges the two ends', (tester) async {
      _tallPhone(tester);
      final rides = _FakeRidesRepository();
      await tester.pumpWidget(_host(mode: ActiveMode.passenger, rides: rides));
      await tester.pumpAndSettle();
      await _setDestination(tester);

      await tester.tap(find.byTooltip('Swap'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find me a rider'));
      await tester.pumpAndSettle();

      // The trip home is the trip in, backwards.
      expect(rides.created?['from'], 'Campus');
      expect(rides.created?['to'], 'Home');
    });
  });

  group('submitting', () {
    testWidgets('Now posts an INSTANT request with no scheduled time', (
      tester,
    ) async {
      _tallPhone(tester);
      final rides = _FakeRidesRepository();
      await tester.pumpWidget(_host(mode: ActiveMode.passenger, rides: rides));
      await tester.pumpAndSettle();
      await _setDestination(tester);

      await tester.tap(find.text('Find me a rider'));
      await tester.pumpAndSettle();

      expect(rides.created?['mode'], 'INSTANT');
      expect(rides.created?['type'], 'REQUEST');
      // The server stamps the request time; sending one would be a guess.
      expect(rides.created?['scheduledAt'], isNull);
      // Posting lands on the waiting screen, not the detail view.
      expect(find.text('waiting ride-1'), findsOneWidget);
    });

    testWidgets('Schedule posts a SCHEDULED ride carrying a time', (
      tester,
    ) async {
      _tallPhone(tester);
      final rides = _FakeRidesRepository();
      await tester.pumpWidget(_host(mode: ActiveMode.rider, rides: rides));
      await tester.pumpAndSettle();
      await _setDestination(tester);
      await _schedule(tester);

      await tester.tap(find.text('Post this ride'));
      await tester.pumpAndSettle();

      expect(rides.created?['mode'], 'SCHEDULED');
      expect(rides.created?['type'], 'OFFER');
      expect(rides.created?['scheduledAt'], isNotNull);
    });

    testWidgets('a rider can post an INSTANT offer', (tester) async {
      _tallPhone(tester);
      final rides = _FakeRidesRepository();
      await tester.pumpWidget(_host(mode: ActiveMode.rider, rides: rides));
      await tester.pumpAndSettle();
      await _setDestination(tester);

      await tester.tap(find.text('Offer this ride now'));
      await tester.pumpAndSettle();

      // "Leaving now, who wants a lift?" — the case the old server gate
      // rejected because it assumed riders went online instead of posting.
      expect(rides.created?['type'], 'OFFER');
      expect(rides.created?['mode'], 'INSTANT');
      expect(rides.created?['scheduledAt'], isNull);
    });

    testWidgets('an approved rider in passenger mode posts a REQUEST', (
      tester,
    ) async {
      // The rider-who-needs-a-lift case: role RIDER, mode PASSENGER. They
      // switch on their profile, and this screen follows.
      _tallPhone(tester);
      final rides = _FakeRidesRepository();
      await tester.pumpWidget(_host(mode: ActiveMode.passenger, rides: rides));
      await tester.pumpAndSettle();
      await _setDestination(tester);

      await tester.tap(find.text('Find me a rider'));
      await tester.pumpAndSettle();

      expect(rides.created?['type'], 'REQUEST');
    });

    testWidgets('posting is blocked until a price has resolved', (
      tester,
    ) async {
      _tallPhone(tester);
      final rides = _FakeRidesRepository(quoteFails: true);
      await tester.pumpWidget(_host(mode: ActiveMode.passenger, rides: rides));
      await tester.pumpAndSettle();
      await _setDestination(tester);

      expect(find.text("Couldn't price this trip"), findsOneWidget);
      await tester.tap(find.text('Find me a rider'));
      await tester.pumpAndSettle();

      // A trip at a fare nobody saw is not postable.
      expect(rides.created, isNull);
    });
  });

  group('gender restriction', () {
    testWidgets('a woman may post a women-only trip', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(
        _host(mode: ActiveMode.passenger, gender: Gender.female),
      );
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      expect(find.text('Women only'), findsOneWidget);
    });

    testWidgets('a man gets no gender control at all', (tester) async {
      _tallPhone(tester);
      await tester.pumpWidget(
        _host(mode: ActiveMode.passenger, gender: Gender.male),
      );
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      // Offering women-only would let him post a trip a woman accepts
      // believing the rider is female.
      expect(find.text('Women only'), findsNothing);
      expect(find.text("WHO I'LL RIDE WITH"), findsNothing);
    });

    testWidgets('no gender recorded means no restriction offered', (
      tester,
    ) async {
      _tallPhone(tester);
      await tester.pumpWidget(_host(mode: ActiveMode.passenger, gender: null));
      await tester.pumpAndSettle();
      await _scrollDown(tester);

      // Fails closed — the server refuses a restricted post from an account
      // with no gender, so the option must not be offered either.
      expect(find.text('Women only'), findsNothing);
    });
  });
}
