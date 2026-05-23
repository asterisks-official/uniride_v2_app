import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/models/ride.dart';

enum RidesFeedStatus { loading, success, error }

class RidesFeedState {
  const RidesFeedState({
    this.rides = const [],
    this.status = RidesFeedStatus.loading,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.errorMessage,
    this.dateFilter,
    this.femaleOnly = false,
  });

  final List<Ride> rides;
  final RidesFeedStatus status;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? errorMessage;
  final String? dateFilter;
  final bool femaleOnly;
}

class RidesFeedNotifier extends Notifier<RidesFeedState> {
  @override
  RidesFeedState build() {
    Future.microtask(() => _fetchPage(1, replace: true));
    return const RidesFeedState();
  }

  Future<void> refresh() => _fetchPage(1, replace: true);

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    await _fetchPage(state.currentPage + 1, replace: false);
  }

  void setDateFilter(String? date) {
    state = RidesFeedState(
      status: RidesFeedStatus.loading,
      dateFilter: date,
      femaleOnly: state.femaleOnly,
    );
    Future.microtask(() => _fetchPage(1, replace: true));
  }

  void setFemaleOnly(bool v) {
    state = RidesFeedState(
      status: RidesFeedStatus.loading,
      dateFilter: state.dateFilter,
      femaleOnly: v,
    );
    Future.microtask(() => _fetchPage(1, replace: true));
  }

  Future<void> _fetchPage(int page, {required bool replace}) async {
    final dateFilter = state.dateFilter;
    final femaleOnly = state.femaleOnly;

    if (replace) {
      state = RidesFeedState(
        status: RidesFeedStatus.loading,
        dateFilter: dateFilter,
        femaleOnly: femaleOnly,
      );
    } else {
      state = RidesFeedState(
        rides: state.rides,
        status: RidesFeedStatus.success,
        isLoadingMore: true,
        hasMore: state.hasMore,
        currentPage: state.currentPage,
        dateFilter: dateFilter,
        femaleOnly: femaleOnly,
      );
    }

    try {
      final result = await ref.read(ridesRepositoryProvider).searchRides(
            date: dateFilter,
            genderPref: femaleOnly ? 'FEMALE_ONLY' : null,
            page: page,
          );

      // Discard if filters changed while the request was in flight.
      if (state.dateFilter != dateFilter || state.femaleOnly != femaleOnly) {
        return;
      }

      final rides =
          replace ? result.items : [...state.rides, ...result.items];

      state = RidesFeedState(
        rides: rides,
        status: RidesFeedStatus.success,
        hasMore: result.meta.page < result.meta.totalPages,
        currentPage: result.meta.page,
        dateFilter: dateFilter,
        femaleOnly: femaleOnly,
      );
    } catch (e) {
      if (state.dateFilter != dateFilter || state.femaleOnly != femaleOnly) {
        return;
      }
      state = RidesFeedState(
        rides: replace ? const [] : state.rides,
        status: RidesFeedStatus.error,
        errorMessage: e.toString(),
        dateFilter: dateFilter,
        femaleOnly: femaleOnly,
      );
    }
  }
}

final ridesFeedProvider =
    NotifierProvider<RidesFeedNotifier, RidesFeedState>(RidesFeedNotifier.new);
