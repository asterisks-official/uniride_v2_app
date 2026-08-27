import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/core/services/maps_launcher.dart';

void main() {
  test('builds the universal Google Maps directions URL', () {
    final uri = directionsUri(lat: 23.8759, lng: 90.3200);

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    // api=1 is what makes this the documented universal form — the Maps app
    // takes it when installed, the browser when not.
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['destination'], '23.8759,90.32');
    expect(uri.queryParameters['travelmode'], 'driving');
  });

  test('negative and fractional coordinates survive encoding', () {
    final uri = directionsUri(lat: -33.8688, lng: 151.2093);
    expect(uri.queryParameters['destination'], '-33.8688,151.2093');
  });
}
