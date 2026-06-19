class AppConstants {
  const AppConstants._();

  // Live backend (Render). Routes are served under /api/v1 (global prefix + URI versioning).
  static const String apiBaseUrl =
      'http://192.168.0.122:3000/api/v1';

  // Socket.IO origin (gateway is mounted on the same host).
  static const String wsUrl = 'http://192.168.0.122:3000';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
