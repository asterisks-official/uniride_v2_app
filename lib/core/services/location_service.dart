import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Why a location request did not produce a position.
///
/// Separate cases because the remedy differs, and telling someone "location
/// unavailable" when the real problem is a switch in Settings is how a
/// feature gets abandoned.
enum LocationFailure {
  /// Declined this time. Asking again later is fine.
  denied,

  /// Declined permanently, or blocked by policy. Only Settings can fix it,
  /// so the UI must offer to open Settings rather than re-prompt.
  deniedForever,

  /// Permission is granted but the device's location switch is off.
  serviceDisabled,

  /// Granted and enabled, but no fix arrived in time — indoors, or a cold
  /// GPS start.
  timeout,
}

/// The outcome of asking where the user is.
sealed class LocationResult {
  const LocationResult();
}

class LocationFound extends LocationResult {
  const LocationFound(this.lat, this.lng);
  final double lat;
  final double lng;
}

class LocationDenied extends LocationResult {
  const LocationDenied(this.reason);
  final LocationFailure reason;

  /// Copy for a snackbar. Says what to do, not what went wrong.
  String get message => switch (reason) {
    LocationFailure.denied =>
      'Location is needed to set your pick-up point. You can also drop the '
          'pin yourself.',
    LocationFailure.deniedForever =>
      'Location is blocked for UniRide. Turn it on in Settings, or drop the '
          'pin yourself.',
    LocationFailure.serviceDisabled =>
      'Turn on location on your phone, or drop the pin yourself.',
    LocationFailure.timeout =>
      "Couldn't get a fix — try again outdoors, or drop the pin yourself.",
  };

  /// Whether offering an "Open settings" action makes sense.
  bool get needsSettings => reason == LocationFailure.deniedForever;
}

/// Where the user is, and the permission dance that gets there.
///
/// **Asked for in context, never cold at launch.** A permission prompt on the
/// first frame — before anyone has seen what the app does — is the one most
/// likely to be denied, and on both platforms a hard denial is expensive to
/// recover from: the system will not ask twice, so the only route back is a
/// trip to Settings that most people never make.
///
/// So every caller here is a screen that has a concrete reason to want a
/// position at the moment it asks: dropping a pin, or going online. The user
/// has already tapped something that plainly needs location, which is what
/// makes the system prompt read as an answer rather than an interruption.
///
/// **Nothing here is ever required.** Every feature that uses location also
/// works without it — the map picker still drags, a pickup point can still be
/// pinned by hand. Denial is a slower path, not a wall.
class LocationService {
  /// Long enough for a cold GPS start, short enough that a screen does not sit
  /// there looking broken.
  static const _timeout = Duration(seconds: 12);

  Future<LocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationDenied(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // The only place the system prompt is raised.
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationDenied(LocationFailure.deniedForever);
    }
    if (permission == LocationPermission.denied) {
      return const LocationDenied(LocationFailure.denied);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // Medium rather than best: a pickup pin does not need sub-metre
          // precision, and asking for it costs seconds and battery.
          accuracy: LocationAccuracy.medium,
          timeLimit: _timeout,
        ),
      );
      return LocationFound(position.latitude, position.longitude);
    } catch (_) {
      // A last known fix beats nothing — it is where the phone was minutes
      // ago, which for setting a pickup point is usually still right.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LocationFound(last.latitude, last.longitude);
      return const LocationDenied(LocationFailure.timeout);
    }
  }

  /// Whether a position could be had without showing a prompt.
  ///
  /// Lets a screen decide whether to offer "use my location" prominently or
  /// quietly, without triggering the permission dialog to find out.
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);
