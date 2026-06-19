import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/models/ride.dart';

class MyRidesNotifier extends AsyncNotifier<List<Ride>> {
  @override
  Future<List<Ride>> build() => _fetch();

  Future<List<Ride>> _fetch() async {
    final result = await ref
        .read(ridesRepositoryProvider)
        .getMyRides(limit: 50);
    return result.items;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}

final myRidesProvider =
    AsyncNotifierProvider<MyRidesNotifier, List<Ride>>(MyRidesNotifier.new);

/// Statuses considered "in flight" — the user has a ride needing attention.
const _activeStatuses = {'SEARCHING', 'MATCHED', 'IN_PROGRESS'};

int _statusRank(String status) => switch (status) {
      'IN_PROGRESS' => 0,
      'MATCHED' => 1,
      'SEARCHING' => 2,
      _ => 3,
    };

/// The single most relevant active ride for the current user, or null.
/// Prioritises by lifecycle (in-progress first), then soonest departure.
final activeRideProvider = Provider<Ride?>((ref) {
  final rides = ref.watch(myRidesProvider).value;
  if (rides == null) return null;

  final active = rides
      .where((r) => _activeStatuses.contains(r.status))
      .toList()
    ..sort((a, b) {
      final byStatus = _statusRank(a.status).compareTo(_statusRank(b.status));
      return byStatus != 0
          ? byStatus
          : a.scheduledAt.compareTo(b.scheduledAt);
    });

  return active.isEmpty ? null : active.first;
});
