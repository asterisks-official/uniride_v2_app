class AppConstants {
  const AppConstants._();

  // Backend origin. Defaults to localhost for development.
  //
  // On a physical device or emulator, run `adb reverse tcp:3000 tcp:3000` once
  // per connection so the device's own localhost:3000 tunnels to the host over
  // USB. This is why the default is `localhost` and not the emulator-only
  // 10.0.2.2 alias — `adb reverse` works for both, a LAN IP would need editing
  // every time the network changes.
  //
  // Override at build time, e.g. for the deployed backend:
  //   flutter run --dart-define=API_ORIGIN=https://uniride-v2-backend.onrender.com
  static const String apiOrigin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'http://localhost:3000',
  );

  // Routes are served under /api/v1 (global prefix + URI versioning).
  static const String apiBaseUrl = '$apiOrigin/api/v1';

  // Socket.IO origin (gateway is mounted on the same host).
  static const String wsUrl = apiOrigin;

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);

  /// Rejections a rider application gets before the account is blocked. Shown
  /// to the applicant as "attempts left"; the server enforces it. Must match
  /// MAX_RIDER_REJECTIONS in the backend's shared/utils/identity.ts.
  static const int maxRiderRejections = 3;
}
