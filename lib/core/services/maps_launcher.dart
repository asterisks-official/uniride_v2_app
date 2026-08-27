import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart'
    show MissingPluginException, PlatformException;
import 'package:url_launcher/url_launcher.dart';

/// Hands a point off to whatever the phone uses for turn-by-turn.
///
/// This app draws the trip; it does not route anyone down it. Google Maps is
/// already open on most riders' handlebars, knows the traffic, and speaks the
/// directions aloud — competing with that is not a good use of anyone's time.
///
/// The `dir/?api=1` form is Google's documented universal URL: the Maps app
/// takes it when installed and the browser takes it when not, so there is no
/// need to probe for the app or keep a `geo:` fallback in step with it.
/// Says the one thing that fixes it, because the exception does not.
void _warnStaleBuild() {
  debugPrint(
    'openDirections: url_launcher has no native half in the running build. '
    'Hot restart cannot add native code — stop the app and run it again.',
  );
}

/// The URL [openDirections] launches. Separated so it can be asserted without
/// a device — the launch itself needs the platform, the address does not.
Uri directionsUri({required double lat, required double lng}) {
  // Coordinates rather than the place name: the name came from a geocoder and
  // may be "Near Hazi Ashraf Ali High School", which Google would have to
  // search for and could resolve somewhere else entirely. The pin is exact.
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$lat,$lng',
    'travelmode': 'driving',
  });
}

Future<bool> openDirections({required double lat, required double lng}) async {
  final uri = directionsUri(lat: lat, lng: lng);

  try {
    // externalApplication, not the in-app webview: the point is to leave for
    // an app that can hold the screen awake and talk while the phone is in a
    // pocket, which an embedded browser cannot do.
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on MissingPluginException {
    _warnStaleBuild();
    return false;
  } on PlatformException catch (err) {
    // Pigeon-based plugins — url_launcher among them — do not raise
    // MissingPluginException when their native half is absent. They fail on
    // the channel itself, which arrives here as `channel-error` and reads like
    // a runtime fault rather than the build problem it is.
    if (err.code == 'channel-error') {
      _warnStaleBuild();
      return false;
    }
    debugPrint('openDirections failed for $uri: $err');
    return false;
  } catch (err) {
    // Was a bare `catch (_) { return false; }`, which turned every cause —
    // missing plugin, no browser, malformed URL — into the same silent false
    // and one indistinguishable snackbar. The reason belongs in the log even
    // when the message to the user stays the same.
    debugPrint('openDirections failed for $uri: $err');
    return false;
  }
}
