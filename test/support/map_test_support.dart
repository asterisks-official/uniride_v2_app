import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Swallows map-tile fetch failures for the duration of a test.
///
/// A widget test has no network, so every tile request fails and Flutter
/// reports each one through `FlutterError.onError` — which the test framework
/// counts as a failure. The map genuinely cannot load tiles here and that is
/// not what any of these tests are about.
///
/// Deliberately narrow: it matches only tile requests, and **re-raises
/// everything else**. A blanket suppressor would hide the overflow, null and
/// assertion errors these tests exist to catch.
void ignoreTileFetchErrors() {
  final previous = FlutterError.onError;

  FlutterError.onError = (details) {
    final text = details.exception.toString();
    final isTileFetch =
        text.contains('tile.openstreetmap.org') ||
        (text.contains('ClientException') && text.contains('.png'));
    if (isTileFetch) return;
    previous?.call(details);
  };

  addTearDown(() => FlutterError.onError = previous);
}
