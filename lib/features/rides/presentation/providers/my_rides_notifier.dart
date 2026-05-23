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
