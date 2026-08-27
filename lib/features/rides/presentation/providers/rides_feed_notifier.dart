import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/account_enums.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
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

  RidesFeedState copyWith({
    List<Ride>? rides,
    RidesFeedStatus? status,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? errorMessage,
    String? dateFilter,
    bool? femaleOnly,
  }) {
    return RidesFeedState(
      rides: rides ?? this.rides,
      status: status ?? this.status,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      errorMessage: errorMessage ?? this.errorMessage,
      dateFilter: dateFilter ?? this.dateFilter,
      femaleOnly: femaleOnly ?? this.femaleOnly,
    );
  }
}

class RidesFeedNotifier extends Notifier<RidesFeedState> {
  StreamSubscription<RealtimeEvent>? _live;

  @override
  RidesFeedState build() {
    Future.microtask(() => _fetchPage(1, replace: true));
    _listenForNewRides();
    ref.onDispose(() => _live?.cancel());
    return const RidesFeedState();
  }

  /// Puts rides on the feed as they are posted, instead of on the next pull.
  ///
  /// The server sends `ride:created` only to users entitled to see it — the
  /// complementary side, same university, gender-safe — so nothing arriving
  /// here needs a permission check. What it does need is the *view* check
  /// below: entitlement is computed from the account's role, while the feed
  /// shows the complement of the mode the user is currently browsing in, and
  /// an approved rider reading the passenger feed is entitled to requests it
  /// must not display.
  void _listenForNewRides() {
    final realtime = ref.read(realtimeServiceProvider);
    // Idempotent, and cheap when a connection is already open.
    unawaited(realtime.connect());

    _live = realtime.events.listen((event) {
      if (event.name != RealtimeEvents.rideCreated) return;
      try {
        _insert(Ride.fromJson(event.data));
      } catch (_) {
        // A card that will not parse is not worth breaking the feed over; the
        // next refresh fetches it properly.
      }
    });
  }

  /// Places a live ride where a refetch would have put it.
  ///
  /// Silently dropped when it does not belong in the feed as it currently
  /// stands — wrong side of the market, or excluded by a filter the user has
  /// set. Inserting it anyway would show a card that vanishes on the next
  /// pull, which reads as a bug in the feed rather than a filter working.
  void _insert(Ride ride) {
    if (state.status != RidesFeedStatus.success) return;
    if (_alreadyListed(ride.id)) return;
    if (!_belongsInFeed(ride)) return;

    // The feed is ordered by departure time, so a new ride goes where its own
    // time puts it — not on top. Prepending would be a lie about a ride
    // leaving tomorrow when the one above it leaves in ten minutes.
    final rides = [...state.rides];
    final at = rides.indexWhere(
      (r) => r.scheduledAt.isAfter(ride.scheduledAt),
    );
    rides.insert(at == -1 ? rides.length : at, ride);

    state = state.copyWith(rides: rides);
  }

  bool _alreadyListed(String id) => state.rides.any((r) => r.id == id);

  bool _belongsInFeed(Ride ride) {
    // Rider mode browses passenger REQUESTs; passenger mode browses rider
    // OFFERs. Same rule the server's own feed query applies.
    final mode = ref.read(profileNotifierProvider).asData?.value.activeMode ??
        ActiveMode.passenger;
    final wanted = mode == ActiveMode.rider ? 'REQUEST' : 'OFFER';
    if (ride.type != wanted) return false;

    if (ride.status != 'SEARCHING') return false;

    if (state.femaleOnly && ride.genderPref != 'FEMALE_ONLY') return false;

    final date = state.dateFilter;
    if (date != null &&
        ride.scheduledAt.toUtc().toIso8601String().substring(0, 10) != date) {
      return false;
    }

    return true;
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

      // Deduplicated on append, because the pages are offset-based over a
      // list that changes underneath them. Post a ride between the page-1 and
      // page-2 fetches and every row shifts down one, so page 2 re-returns the
      // last row of page 1 — which is exactly what testing two devices does,
      // and exactly the duplicate cards it produced.
      //
      // Keyed on id, keeping the copy already on screen: the incoming one is
      // no fresher, and replacing it would rebuild a card the user may be
      // mid-tap on.
      final List<Ride> rides;
      if (replace) {
        rides = result.items;
      } else {
        final seen = state.rides.map((r) => r.id).toSet();
        rides = [
          ...state.rides,
          ...result.items.where((r) => seen.add(r.id)),
        ];
      }

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
