import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/core/di/providers.dart';
import 'package:uniride_app/core/services/location_service.dart';
import 'package:uniride_app/core/theme/app_theme.dart';
import 'package:uniride_app/features/places/data/repositories/geocoding_repository.dart';
import 'package:uniride_app/features/places/data/repositories/places_repository.dart';
import 'package:uniride_app/features/places/domain/models/place_suggestion.dart';
import 'package:uniride_app/features/places/domain/models/saved_place.dart';
import 'package:uniride_app/features/places/presentation/screens/location_picker_screen.dart';
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
  _FakeGeocodingRepository({
    this.results = const [],
    this.fails = false,
    this.resolvesTo,
    this.label = 'Mirpur 10',
    this.placeName,
  });

  final List<PlaceSuggestion> results;
  final bool fails;
  final PickedPlace? resolvesTo;
  final String label;

  /// The specific thing at the pin. Defaults to [label] — the case where the
  /// point is nothing more notable than its own neighbourhood.
  final String? placeName;

  int searchCount = 0;
  int resolveCount = 0;

  @override
  Future<List<PlaceSuggestion>> search(String query) async {
    searchCount++;
    if (fails) throw const NetworkException('No internet connection');
    return results;
  }

  @override
  Future<PickedPlace?> resolve(PlaceSuggestion suggestion) async {
    resolveCount++;
    return resolvesTo;
  }

  @override
  Future<String> reverse(double lat, double lng) async => placeName ?? label;
}

/// Stands in for the GPS. Extends rather than implements so the permission
/// logic in the real service is bypassed entirely — a widget test has no
/// platform channel to answer it.
class _FakeLocationService extends LocationService {
  _FakeLocationService(this.result);

  final LocationResult result;
  int calls = 0;

  @override
  Future<LocationResult> current() async {
    calls++;
    return result;
  }
}

const _home = SavedPlace(
  id: 'p1',
  label: 'Home',
  lat: 23.8069,
  lng: 90.3668,
  areaLabel: 'Mirpur 10',
);

const _diu = PlaceSuggestion(
  id: 'ChIJ_diu',
  primary: 'Daffodil International University',
  secondary: 'Ashulia, Savar',
);

/// Records what the picker returned, so "did it confirm?" is assertable.
class _Harness {
  PickedPlace? result;
  bool closed = false;
}

Widget _host(
  _Harness harness, {
  List<SavedPlace> places = const [_home],
  GeocodingRepository? geocoding,
  LocationService? location,
  bool locateOnOpen = false,
}) {
  return ProviderScope(
    overrides: [
      placesRepositoryProvider.overrideWithValue(_FakePlacesRepository(places)),
      geocodingRepositoryProvider.overrideWithValue(
        geocoding ?? _FakeGeocodingRepository(),
      ),
      if (location != null) locationServiceProvider.overrideWithValue(location),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                harness.result = await LocationPickerScreen.open(
                  context,
                  title: 'Where are you starting from?',
                  locateOnOpen: locateOnOpen,
                );
                harness.closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openPicker(WidgetTester tester) async {
  ignoreTileFetchErrors();
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  group('the pin is the answer', () {
    testWidgets('opens straight onto the map, not a list', (tester) async {
      await tester.pumpWidget(_host(_Harness()));
      await _openPicker(tester);

      // The map is the screen. Confirming the pin is the primary action.
      expect(find.text('Confirm this point'), findsOneWidget);
      expect(
        find.textContaining('Drag the map to move the pin'),
        findsOneWidget,
      );
    });

    testWidgets('names whatever the pin is over', (tester) async {
      await tester.pumpWidget(
        _host(
          _Harness(),
          geocoding: _FakeGeocodingRepository(label: 'Uttara Sector 7'),
        ),
      );
      await _openPicker(tester);

      expect(find.text('Uttara Sector 7'), findsOneWidget);
    });

    testWidgets('confirming returns the pin coordinate, not an area centre', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(_host(harness));
      await _openPicker(tester);

      await tester.tap(find.text('Confirm this point'));
      await tester.pumpAndSettle();

      expect(harness.closed, isTrue);
      // Dhaka default centre — the map's own position, not a list entry.
      expect(harness.result?.lat, closeTo(23.7806, 0.0001));
      expect(harness.result?.lng, closeTo(90.4074, 0.0001));
      expect(harness.result?.areaLabel, 'Mirpur 10');
    });

    testWidgets('names the exact place, never the neighbourhood', (
      tester,
    ) async {
      // Pinning a university and being told "Ashulia" helps neither the
      // person pinning nor the rider who has to find them.
      final harness = _Harness();
      await tester.pumpWidget(
        _host(
          harness,
          geocoding: _FakeGeocodingRepository(
            placeName: 'Daffodil International University',
          ),
        ),
      );
      await _openPicker(tester);

      expect(find.text('Daffodil International University'), findsOneWidget);

      await tester.tap(find.text('Confirm this point'));
      await tester.pumpAndSettle();

      // The exact name travels with the point, both as what the poster sees
      // and as what is published.
      expect(harness.result?.displayName, 'Daffodil International University');
      expect(harness.result?.areaLabel, 'Daffodil International University');
    });
  });

  group('search moves the map, it does not answer for it', () {
    testWidgets('tapping a result keeps the picker open', (tester) async {
      final geo = _FakeGeocodingRepository(
        results: const [_diu],
        resolvesTo: const PickedPlace(
          lat: 23.8759,
          lng: 90.3204,
          areaLabel: 'Ashulia',
        ),
      );
      final harness = _Harness();
      await tester.pumpWidget(_host(harness, geocoding: geo));
      await _openPicker(tester);
      await _search(tester, 'daffodil');

      await tester.tap(find.text('Daffodil International University'));
      await tester.pumpAndSettle();

      // A search result is an approximation — a building's door, or the middle
      // of a neighbourhood. The user still adjusts and confirms.
      expect(geo.resolveCount, 1);
      expect(harness.closed, isFalse);
      expect(find.text('Confirm this point'), findsOneWidget);
    });

    testWidgets('a result that will not resolve says so and stays put', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(
        _host(
          harness,
          geocoding: _FakeGeocodingRepository(results: const [_diu]),
        ),
      );
      await _openPicker(tester);
      await _search(tester, 'daffodil');

      await tester.tap(find.text('Daffodil International University'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not find that place'), findsOneWidget);
      expect(harness.closed, isFalse);
    });

    testWidgets('debounces so a typed word is one request, not five', (
      tester,
    ) async {
      final geo = _FakeGeocodingRepository(results: const [_diu]);
      await tester.pumpWidget(_host(_Harness(), geocoding: geo));
      await _openPicker(tester);

      for (final text in ['d', 'da', 'daf', 'daff', 'daffo']) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(geo.searchCount, 1);
    });

    testWidgets('no results points back at the pin', (tester) async {
      await tester.pumpWidget(
        _host(_Harness(), geocoding: _FakeGeocodingRepository()),
      );
      await _openPicker(tester);
      await _search(tester, 'zzzzz');

      expect(find.text('Nothing found'), findsOneWidget);
      expect(find.textContaining('drag the pin instead'), findsOneWidget);
    });

    testWidgets('a failed search is distinguished from an empty one', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_Harness(), geocoding: _FakeGeocodingRepository(fails: true)),
      );
      await _openPicker(tester);
      await _search(tester, 'mirpur');

      expect(find.text('Search is unavailable'), findsOneWidget);
    });
  });

  group('opening on the user', () {
    testWidgets('"where are you now" starts at the device position', (
      tester,
    ) async {
      final harness = _Harness();
      final gps = _FakeLocationService(const LocationFound(23.8759, 90.3204));
      await tester.pumpWidget(
        _host(harness, location: gps, locateOnOpen: true),
      );
      await _openPicker(tester);

      expect(gps.calls, 1);

      await tester.tap(find.text('Confirm this point'));
      await tester.pumpAndSettle();

      // The pin followed the fix, so confirming without touching anything
      // returns where the phone is — not the Dhaka fallback centre.
      expect(harness.result?.lat, closeTo(23.8759, 0.0001));
      expect(harness.result?.lng, closeTo(90.3204, 0.0001));
    });

    testWidgets('a refusal is silent and leaves the map usable', (
      tester,
    ) async {
      final harness = _Harness();
      final gps = _FakeLocationService(
        const LocationDenied(LocationFailure.deniedForever),
      );
      await tester.pumpWidget(
        _host(harness, location: gps, locateOnOpen: true),
      );
      await _openPicker(tester);

      // No snackbar on open — the pin was always the answer anyway.
      expect(find.textContaining('blocked for UniRide'), findsNothing);
      expect(find.text('Confirm this point'), findsOneWidget);

      await tester.tap(find.text('Confirm this point'));
      await tester.pumpAndSettle();
      expect(harness.result?.lat, closeTo(23.7806, 0.0001));
    });

    testWidgets('a destination picker never asks for the position', (
      tester,
    ) async {
      // Centring "where are you going?" on the user gives them a point whose
      // only use is to be dragged away from.
      final gps = _FakeLocationService(const LocationFound(23.87, 90.32));
      await tester.pumpWidget(_host(_Harness(), location: gps));
      await _openPicker(tester);

      expect(gps.calls, 0);
    });
  });

  group('saved places', () {
    testWidgets('are listed under the pin panel', (tester) async {
      await tester.pumpWidget(_host(_Harness()));
      await _openPicker(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('SAVED PLACES'), findsOneWidget);
    });

    testWidgets('confirm immediately — they are already exact', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(_host(harness));
      await _openPicker(tester);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // The user pinned this point themselves, so unlike a search result it
      // needs no adjusting.
      expect(harness.closed, isTrue);
      expect(harness.result?.lat, _home.lat);
      expect(harness.result?.lng, _home.lng);
      expect(harness.result?.savedPlaceId, _home.id);
    });

    testWidgets('an empty list leaves the map perfectly usable', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_Harness(), places: const []));
      await _openPicker(tester);

      expect(find.text('SAVED PLACES'), findsNothing);
      // No dead end — the pin was always the answer anyway.
      expect(find.text('Confirm this point'), findsOneWidget);
    });
  });
}
