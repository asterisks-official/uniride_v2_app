import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/models/driver_availability.dart';

/// This rider's availability, and the one control that changes it.
///
/// Optimistic on the way in — the toggle flips before the server answers,
/// because a switch that lags a round-trip feels broken — and rolls back on
/// failure rather than leaving the UI claiming something untrue.
class AvailabilityNotifier extends AsyncNotifier<DriverAvailability> {
  @override
  Future<DriverAvailability> build() =>
      ref.read(driversRepositoryProvider).getMine();

  /// Throws [AppException] so the caller can show why — "share your location"
  /// and "complete verification" are both actionable messages, not noise.
  Future<void> setOnline({
    required bool isOnline,
    double? lat,
    double? lng,
  }) async {
    final previous = state;
    state = AsyncData(
      DriverAvailability(
        isOnline: isOnline,
        // Not dispatchable until the server confirms: claiming otherwise
        // would tell a rider they are getting trips when they may not be.
        dispatchable: false,
        lat: lat,
        lng: lng,
      ),
    );

    try {
      state = AsyncData(
        await ref
            .read(driversRepositoryProvider)
            .setOnline(isOnline: isOnline, lat: lat, lng: lng),
      );
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Reports a position without changing the online flag.
  Future<void> heartbeat({required double lat, required double lng}) async {
    if (state.asData?.value.isOnline != true) return;
    await ref.read(driversRepositoryProvider).heartbeat(lat: lat, lng: lng);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(driversRepositoryProvider).getMine(),
    );
  }
}

final availabilityProvider =
    AsyncNotifierProvider<AvailabilityNotifier, DriverAvailability>(
      AvailabilityNotifier.new,
    );
