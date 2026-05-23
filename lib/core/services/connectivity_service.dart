import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` when the device has any network connection, `false` otherwise.
/// Starts with an initial connectivity check before streaming changes.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final results = await Connectivity().checkConnectivity();
  yield _hasConnection(results);
  yield* Connectivity()
      .onConnectivityChanged
      .map((r) => _hasConnection(r));
});

bool _hasConnection(List<ConnectivityResult> results) =>
    results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
