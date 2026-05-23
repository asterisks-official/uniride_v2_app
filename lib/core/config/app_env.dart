// Pass --dart-define=FLAVOR=prod at build time for production.
// Default is dev which shows debug helpers (devOtp hints, verbose errors).
abstract final class AppEnv {
  static const flavor =
      String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  static bool get isDev => flavor != 'prod';
}
