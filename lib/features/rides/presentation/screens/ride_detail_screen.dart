import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/di/providers.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/maps_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/slide_action.dart';
import '../../../../shared/widgets/trust_score_ring.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/models/ride.dart';
import '../../domain/models/ride_request.dart';
import '../providers/compose_ride_notifier.dart' show rideQuoteProvider;
import '../providers/my_rides_notifier.dart';
import '../widgets/trip_map.dart';

// Public so ride_requests_screen can invalidate after responding.
final rideDetailProvider = FutureProvider.autoDispose.family<Ride, String>((
  ref,
  rideId,
) {
  return ref.read(ridesRepositoryProvider).getRide(rideId);
});

class RideDetailScreen extends ConsumerStatefulWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends ConsumerState<RideDetailScreen> {
  StreamSubscription<RealtimeEvent>? _live;

  @override
  void initState() {
    super.initState();

    // Every handshake on this screen has its two halves on two different
    // phones: the rider starts and the passenger confirms, then both confirm
    // completion. Without this the second person sits on a screen that will
    // not change until they pull to refresh, which is what makes the step feel
    // broken rather than pending.
    final realtime = ref.read(realtimeServiceProvider);
    unawaited(realtime.connect());
    _live = realtime.events.listen((event) {
      if (event.name != RealtimeEvents.rideUpdated &&
          event.name != RealtimeEvents.rideMatched) {
        return;
      }
      if (event.data['id'] != widget.rideId) return;
      // Refetch rather than trusting the payload: this screen's shape includes
      // a pending-request count the broadcast has no reason to keep current.
      ref.invalidate(rideDetailProvider(widget.rideId));
    });
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  bool _joining = false;
  RideRequest? _joinedRequest;
  bool _actioning = false;
  String? _error;

  // ── Passenger: request to join ─────────────────────────────────────────────

  Future<void> _requestJoin() async {
    final ride = ref.read(rideDetailProvider(widget.rideId)).asData?.value;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final req = await ref
          .read(ridesRepositoryProvider)
          .requestRide(widget.rideId);
      if (mounted) {
        setState(() {
          _joining = false;
          _joinedRequest = req;
        });

        // Whose reply is being waited on depends on which way round the post
        // is: joining an OFFER waits on its rider, answering a REQUEST waits
        // on the passenger who asked. "The rider will respond" was wrong half
        // the time.
        final them = ride?.type == 'REQUEST' ? 'passenger' : 'rider';
        showAppSnack(
          context,
          // No "shortly" — the app cannot promise a stranger's response time,
          // and a promise it does not keep is worse than no promise. What it
          // can say is how the answer will arrive.
          'Request sent. We\'ll notify you if the $them accepts.',
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _joining = false;
          _error = message;
        });
        // Also as a toast, not only in the banner. The banner lives in the
        // scrolling content while the slider is pinned to the bottom bar, so
        // sliding from the top of the page would otherwise fail into a
        // message that is several hundred pixels off screen.
        showAppSnack(context, message, isError: true);
      }
    }
  }

  // ── Rider lifecycle actions ────────────────────────────────────────────────

  Future<void> _riderAction(Future<void> Function() action) async {
    setState(() {
      _actioning = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        ref.invalidate(rideDetailProvider(widget.rideId));
        ref.invalidate(myRidesProvider);
        setState(() => _actioning = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actioning = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  /// Where this phone is, for the handshake record — or nothing.
  ///
  /// Best effort by design. A denied permission, a cold GPS or a stairwell
  /// must not stop someone starting or ending a trip, so this never throws and
  /// gives up quickly: a stamp is worth having, and not worth making anyone
  /// stand in the road waiting for.
  Future<({double lat, double lng})?> _here() async {
    try {
      final result = await ref
          .read(locationServiceProvider)
          .current()
          .timeout(const Duration(seconds: 6));
      if (result is LocationFound) {
        return (lat: result.lat, lng: result.lng);
      }
    } catch (_) {
      // Timed out or the platform refused. Unknown is a truthful answer.
    }
    return null;
  }

  Future<void> _startRide() => _riderAction(() async {
    final at = await _here();
    await ref
        .read(ridesRepositoryProvider)
        .startRide(widget.rideId, lat: at?.lat, lng: at?.lng);
  });

  /// The passenger agreeing the trip has begun. Until this lands the ride is
  /// matched but not under way, and still cancellable.
  Future<void> _confirmStart() => _riderAction(() async {
    final at = await _here();
    await ref
        .read(ridesRepositoryProvider)
        .confirmStart(widget.rideId, lat: at?.lat, lng: at?.lng);
  });

  Future<void> _confirmRide() => _riderAction(() async {
    final at = await _here();
    final status = await ref
        .read(ridesRepositoryProvider)
        .confirmRide(widget.rideId, lat: at?.lat, lng: at?.lng);

    // Whoever confirms second ends the ride, and finds out from their own
    // response rather than from the broadcast that follows it. The other side
    // still learns over the socket — this only removes the round-trip for the
    // person holding the phone that did it.
    if (status == 'COMPLETED' && mounted) {
      context.pushReplacement('/rides/${widget.rideId}/pay');
    }
  });

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel ride?'),
        content: const Text(
          'This will notify the passenger and the ride will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep ride'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _riderAction(
        () => ref.read(ridesRepositoryProvider).cancelRide(widget.rideId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // A completed ride is never something to sit and look at — both people
    // owe each other money and a rating. Driven off the ride's own state
    // rather than off the socket, so a missed broadcast still lands: Android
    // suspends sockets on backgrounding and nothing replays what was sent
    // while the app was asleep, but the next refetch shows COMPLETED.
    ref.listen(rideDetailProvider(widget.rideId), (prev, next) {
      final was = prev?.asData?.value.status;
      final now = next.asData?.value.status;
      if (now != 'COMPLETED' || was == 'COMPLETED' || !mounted) return;
      context.pushReplacement('/rides/${widget.rideId}/pay');
    });

    final async = ref.watch(rideDetailProvider(widget.rideId));
    final auth = ref.watch(authNotifierProvider);
    final currentUserId = auth is Authenticated ? auth.user.id : null;

    // Three states, three sets of chrome. Only the loaded one has a map to put
    // a back button on top of, so only it drops the app bar — a skeleton under
    // a transparent bar is a screen with no visible way out.
    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Ride')),
        body: const RideDetailSkeleton(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Ride')),
        body: ErrorRetry(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(rideDetailProvider(widget.rideId)),
        ),
      ),
      data: (ride) => _RideDetailBody(
        ride: ride,
        currentUserId: currentUserId,
        joining: _joining,
        joinedRequest: _joinedRequest,
        actioning: _actioning,
        error: _error,
        onJoin: _requestJoin,
        onViewRequests: () async {
          await context.push('/rides/${widget.rideId}/requests');
          if (mounted) ref.invalidate(rideDetailProvider(widget.rideId));
        },
        onStartRide: _startRide,
        onCancelRide: _cancelRide,
        onConfirmRide: _confirmRide,
        onConfirmStart: _confirmStart,
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _RideDetailBody extends ConsumerWidget {
  const _RideDetailBody({
    required this.ride,
    required this.currentUserId,
    required this.joining,
    required this.joinedRequest,
    required this.actioning,
    required this.error,
    required this.onJoin,
    required this.onViewRequests,
    required this.onStartRide,
    required this.onCancelRide,
    required this.onConfirmRide,
    required this.onConfirmStart,
  });

  final Ride ride;
  final String? currentUserId;
  final bool joining;
  final RideRequest? joinedRequest;
  final bool actioning;
  final String? error;
  final VoidCallback onJoin;
  final VoidCallback onViewRequests;
  final VoidCallback onStartRide;
  final VoidCallback onCancelRide;
  final VoidCallback onConfirmRide;
  final VoidCallback onConfirmStart;

  bool get _isRider => currentUserId != null && currentUserId == ride.riderId;

  /// Someone actually on this trip, as opposed to browsing it.
  bool get _isParticipant =>
      currentUserId != null &&
      (currentUserId == ride.riderId || currentUserId == ride.passenger?.id);

  /// Turn-by-turn is only useful once there is somewhere to be, and only to
  /// the two people going there.
  /// The pickup is only a destination for the rider on their way to it.
  bool get _toPickup => _isRider && ride.status == 'MATCHED';

  bool get _canNavigate =>
      ride.hasRoute &&
      _isParticipant &&
      (ride.status == 'MATCHED' || ride.status == 'IN_PROGRESS');

  /// Owner controls on a searching post go to its creator on both sides;
  /// without that, a passenger who posted a REQUEST would be offered a
  /// "Request to Join" button on their own ride.
  Widget get _cta => (_isRider || (_isOwner && ride.status == 'SEARCHING'))
      ? _RiderCTA(
          ride: ride,
          actioning: actioning,
          onViewRequests: onViewRequests,
          onStartRide: onStartRide,
          onCancelRide: onCancelRide,
          onConfirmRide: onConfirmRide,
        )
      : _PassengerCTA(
          ride: ride,
          currentUserId: currentUserId,
          joining: joining,
          joinedRequest: joinedRequest,
          onJoin: onJoin,
          onConfirm: onConfirmRide,
          onConfirmStart: onConfirmStart,
          actioning: actioning,
        );

  /// Whoever posted the ride — for a REQUEST that is the passenger, who still
  /// owns the post (view requests, cancel) even though they are not the rider.
  bool get _isOwner =>
      currentUserId != null && currentUserId == ride.creator.id;

  /// The road between the ends, if the server can draw one.
  ///
  /// Reuses the quote the compose screen already asked for — same two points,
  /// same cached answer — so the line is usually there on the first frame.
  /// A miss is not an error: [TripMap] falls back to a dotted straight line,
  /// which is honest about being an approximation.
  List<LatLng> _routeFor(WidgetRef ref) {
    if (!ride.hasRoute) return const [];
    final quote = ref
        .watch(
          rideQuoteProvider((
            fromLat: ride.originLat!,
            fromLng: ride.originLng!,
            toLat: ride.destLat!,
            toLng: ride.destLng!,
          )),
        )
        .asData
        ?.value;
    return [
      for (final (lat, lng) in quote?.polyline ?? const <(double, double)>[])
        LatLng(lat, lng),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rider = ride.poster;

    return Scaffold(
      backgroundColor: AppColors.background,
      // A real bottom bar, not a Positioned child of a Stack. Scaffold reserves
      // its height and — the reason this changed — ScaffoldMessenger lifts
      // floating snackbars above it. As an overlay it sat on top of the slider
      // the user had just moved, hiding the control while confirming it.
      bottomNavigationBar: _ActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_canNavigate) ...[
              // Only one person is travelling to the pickup, and it is not the
              // passenger — the pickup is where they already are. Sending them
              // there opens Google Maps on the spot they are standing on,
              // which reads as the app pointing at the wrong place.
              //
              // So: the rider is routed to the pickup until the trip starts.
              // Everyone else, and everyone once it has, goes to the drop-off.
              _NavigateButton(
                lat: _toPickup ? ride.originLat! : ride.destLat!,
                lng: _toPickup ? ride.originLng! : ride.destLng!,
                label: _toPickup
                    ? 'Navigate to pickup'
                    : 'Navigate to drop-off',
              ),
              const SizedBox(height: 10),
            ],
            _cta,
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // The trip, first and largest. This screen answers "where does it
          // go, and is it worth it?" — questions a list of labelled rows is
          // a poor way to ask. It collapses to a plain bar on scroll so the
          // detail below is never fighting it for room.
          _MapHeader(ride: ride, route: _routeFor(ref)),

          // A trip under way is a different screen from a trip being
          // considered. Fare and departure answer "shall I take this?", which
          // by now is settled — what matters is that it is running, how long
          // it has been, and where it ends.
          //
          // Otherwise the fare and departure summary, promoted out of the chip
          // grid: they were two chips among five, at the same weight as the
          // seat count.
          SliverToBoxAdapter(
            child: ride.status == 'IN_PROGRESS'
                ? _TripBanner(ride: ride)
                : _Summary(ride: ride),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    label: ride.type == 'REQUEST' ? 'PASSENGER' : 'RIDER',
                  ),
                  const SizedBox(height: 10),
                  _PosterCard(rider: rider, isYou: _isRider),
                  const SizedBox(height: 22),

                  if (_isRider && ride.passenger != null) ...[
                    _SectionTitle(label: 'MATCHED WITH'),
                    const SizedBox(height: 10),
                    _PassengerCard(passenger: ride.passenger!),
                    const SizedBox(height: 22),
                  ],

                  _SectionTitle(label: 'ROUTE'),
                  const SizedBox(height: 10),
                  _RouteRow(from: ride.originAddress, to: ride.destAddress),
                  const SizedBox(height: 22),

                  _SectionTitle(label: 'DETAILS'),
                  const SizedBox(height: 10),
                  _DetailGrid(ride: ride),

                  if (error != null) ...[
                    const SizedBox(height: 20),
                    _ErrorBanner(message: error!),
                  ],
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Rider CTA ─────────────────────────────────────────────────────────────────

class _RiderCTA extends StatelessWidget {
  const _RiderCTA({
    required this.ride,
    required this.actioning,
    required this.onViewRequests,
    required this.onStartRide,
    required this.onCancelRide,
    required this.onConfirmRide,
  });

  final Ride ride;
  final bool actioning;
  final VoidCallback onViewRequests;
  final VoidCallback onStartRide;
  final VoidCallback onCancelRide;
  final VoidCallback onConfirmRide;

  @override
  Widget build(BuildContext context) {
    switch (ride.status) {
      case 'SEARCHING':
        final pending = ride.pendingRequestCount ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.people_outline),
              label: Text(
                pending > 0
                    ? '$pending pending request${pending != 1 ? 's' : ''}'
                    : 'View Requests',
              ),
              onPressed: onViewRequests,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: actioning ? null : onCancelRide,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              child: actioning
                  ? const _Spinner(color: AppColors.error)
                  : const Text('Cancel Ride'),
            ),
          ],
        );

      case 'MATCHED':
        // Started, but the trip is not under way until the passenger says so.
        if (ride.awaitingStartConfirmation) {
          return const _StatusChip(
            label: 'Started · waiting for the passenger to confirm',
            color: AppColors.muted,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.directions_car),
              label: actioning
                  ? const _Spinner(color: Colors.white)
                  : const Text('Start Ride'),
              onPressed: actioning ? null : onStartRide,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: actioning ? null : onCancelRide,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              child: const Text('Cancel Ride'),
            ),
          ],
        );

      case 'IN_PROGRESS':
        // A ride ends when both sides agree it did. Pressing confirm sets your
        // half and leaves the status at IN_PROGRESS, so re-offering the button
        // reads as "that did nothing" — and pressing it again is a 409.
        if (ride.riderConfirmed) {
          return const _StatusChip(
            label: 'You confirmed · waiting for the passenger',
            color: AppColors.muted,
          );
        }
        // Dragged, not tapped — and deliberately not the same control as the
        // one that started the ride.
        //
        // The two used to be identical buttons in the identical spot: "Start
        // Ride", then "Confirm Completion" a moment later in the same pixels.
        // A second reflexive tap where the first one landed would end a trip
        // that had just begun, and ending it is what puts it beyond cancelling
        // and asks both people to rate each other.
        return SlideAction(
          label: 'Slide to end ride',
          busyLabel: 'Ending ride',
          busy: actioning,
          icon: Icons.flag_outlined,
          color: AppColors.error,
          onConfirm: onConfirmRide,
        );

      case 'COMPLETED':
        return const _StatusChip(
          label: 'Ride completed',
          color: AppColors.success,
        );

      case 'CANCELLED':
        return const _StatusChip(
          label: 'Ride cancelled',
          color: AppColors.muted,
        );

      case 'EXPIRED':
        return const _StatusChip(
          label: 'Expired — nobody took this ride',
          color: AppColors.muted,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Passenger CTA ─────────────────────────────────────────────────────────────

class _PassengerCTA extends StatelessWidget {
  const _PassengerCTA({
    required this.ride,
    required this.currentUserId,
    required this.joining,
    required this.joinedRequest,
    required this.onJoin,
    required this.onConfirm,
    required this.onConfirmStart,
    required this.actioning,
  });

  final Ride ride;
  final String? currentUserId;
  final bool joining;
  final RideRequest? joinedRequest;
  final VoidCallback onJoin;
  final VoidCallback onConfirm;
  final VoidCallback onConfirmStart;
  final bool actioning;

  bool get _isPassenger =>
      currentUserId != null && ride.passenger?.id == currentUserId;

  @override
  Widget build(BuildContext context) {
    if (joinedRequest != null) {
      return const _StatusChip(label: 'Request sent', color: AppColors.success);
    }

    switch (ride.status) {
      case 'SEARCHING':
        // Dragged, not tapped. This is the one irreversible thing a passenger
        // can do from a screen they are scrolling through, and it puts their
        // name in front of a stranger — a mis-tap on the way past should not
        // be able to do it.
        return SlideAction(
          label: 'Slide to request',
          busyLabel: 'Sending request',
          busy: joining,
          onConfirm: onJoin,
        );

      case 'MATCHED':
        if (_isPassenger) {
          // The rider says they have set off; the ride waits on this.
          if (ride.awaitingStartConfirmation) {
            return ElevatedButton.icon(
              icon: const Icon(Icons.play_circle_outline),
              label: actioning
                  ? const _Spinner(color: Colors.white)
                  : const Text('Confirm ride started'),
              onPressed: actioning ? null : onConfirmStart,
            );
          }
          return const _StatusChip(
            label: 'You\'re matched! Waiting for rider to start.',
            color: AppColors.success,
          );
        }
        return const _StatusChip(label: 'Ride matched', color: AppColors.muted);

      case 'IN_PROGRESS':
        if (_isPassenger) {
          if (ride.passengerConfirmed) {
            return const _StatusChip(
              label: 'You confirmed · waiting for the rider',
              color: AppColors.muted,
            );
          }
          // The passenger's hazard is sharper than the rider's: they tap
          // "Confirm ride started", the screen swaps beneath their thumb, and
          // the same spot now ends the ride. A slide cannot be hit by
          // momentum.
          return SlideAction(
            label: 'Slide to end ride',
            busyLabel: 'Ending ride',
            busy: actioning,
            icon: Icons.flag_outlined,
            color: AppColors.error,
            onConfirm: onConfirm,
          );
        }
        return const _StatusChip(
          label: 'Ride in progress',
          color: AppColors.muted,
        );

      case 'COMPLETED':
        return const _StatusChip(
          label: 'Ride completed',
          color: AppColors.success,
        );

      case 'CANCELLED':
        return const _StatusChip(
          label: 'Ride cancelled',
          color: AppColors.muted,
        );

      case 'EXPIRED':
        return const _StatusChip(
          label: 'Expired — nobody took this ride',
          color: AppColors.muted,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({required this.passenger});
  final PassengerSummary passenger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.segmentTrack,
            backgroundImage: passenger.profilePictureUrl != null
                ? CachedNetworkImageProvider(passenger.profilePictureUrl!)
                : null,
            child: passenger.profilePictureUrl == null
                ? Text(
                    passenger.name.isNotEmpty
                        ? passenger.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            passenger.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// The trip, as a collapsing header.
///
/// Pinned so the back button never scrolls away, and stretchy so an overscroll
/// reveals more map rather than a blank gap.
class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.ride, required this.route});

  final Ride ride;
  final List<LatLng> route;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      title: Text(
        ride.type == 'REQUEST' ? 'Ride request' : 'Ride offer',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      // The bar's own title only belongs to the collapsed state; expanded, the
      // map should be uninterrupted.
      titleSpacing: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (ride.hasRoute)
              TripMap(
                origin: LatLng(ride.originLat!, ride.originLng!),
                destination: LatLng(ride.destLat!, ride.destLng!),
                route: route,
                // Room at the top for the bar, and at the bottom for the
                // summary card that overlaps the map's lower edge.
                padding: const EdgeInsets.fromLTRB(40, 96, 40, 64),
              )
            else
              const _NoRoute(),
            // Keeps the back button and title legible over whatever the map
            // happens to draw underneath them.
            const _TopScrim(),
          ],
        ),
      ),
    );
  }
}

/// A ride posted before two-point trips existed has no coordinates to draw.
class _NoRoute extends StatelessWidget {
  const _NoRoute();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.segmentTrack,
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 32, color: AppColors.muted),
          SizedBox(height: 8),
          Text(
            'No map for this ride',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.dark.withValues(alpha: 0.30),
            AppColors.dark.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45],
        ),
      ),
    ),
  );
}

/// Fare and departure, at the weight they actually carry.
class _Summary extends StatelessWidget {
  const _Summary({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final dt = ride.scheduledAt.toLocal();
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final instant = ride.mode == 'INSTANT';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FARE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '৳${ride.fare.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                instant ? 'LEAVING' : 'DEPARTS',
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                instant ? 'Now' : '$h:$m $period',
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The header for a ride that is actually happening.
///
/// Replaces the fare-and-departure summary once the trip starts. It ticks,
/// deliberately: a running clock is what makes a screen read as live, and both
/// people are watching the same number.
class _TripBanner extends StatefulWidget {
  const _TripBanner({required this.ride});

  final Ride ride;

  @override
  State<_TripBanner> createState() => _TripBannerState();
}

class _TripBannerState extends State<_TripBanner> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Half-minute, not per second. The number is in whole minutes, so a
    // faster tick would repaint to show the same thing.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get _elapsed {
    final from = widget.ride.startedAt;
    if (from == null) return 'Under way';
    final mins = DateTime.now().difference(from).inMinutes;
    if (mins < 1) return 'Just started';
    if (mins < 60) return '$mins min so far';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h so far' : '${h}h ${m}m so far';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryWash,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LivePulse(),
              const SizedBox(width: 9),
              const Text(
                'RIDE IN PROGRESS',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              Text(
                _elapsed,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Heading to',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.ride.destAddress,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '৳${widget.ride.fare.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A dot that breathes — the only thing on the screen saying "this is now".
class _LivePulse extends StatefulWidget {
  const _LivePulse();

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
    child: Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    ),
  );
}

/// Whoever posted the ride.
class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.rider, required this.isYou});

  final RiderSummary rider;
  final bool isYou;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.segmentTrack,
            backgroundImage: rider.profilePictureUrl != null
                ? CachedNetworkImageProvider(rider.profilePictureUrl!)
                : null,
            child: rider.profilePictureUrl == null
                ? Text(
                    rider.name.isNotEmpty ? rider.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 19,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rider.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isYou) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${rider.averageRating.toStringAsFixed(1)} · '
                      '${rider.ridesCompleted} rides',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TrustScoreRing(score: 50, size: 40),
        ],
      ),
    );
  }
}

/// Hands the trip to Google Maps.
///
/// Secondary styling on purpose: it sits directly above the button that
/// actually advances the ride, and leaving the app is not the thing this
/// screen is for.
class _NavigateButton extends StatelessWidget {
  const _NavigateButton({
    required this.lat,
    required this.lng,
    required this.label,
  });

  final double lat;
  final double lng;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.navigation_outlined, size: 19),
      label: Text(label),
      onPressed: () async {
        final ok = await openDirections(lat: lat, lng: lng);
        // A phone with no maps app and no browser is rare but not impossible,
        // and a button that silently does nothing is worse than one that says
        // so — the coordinates are on screen either way.
        if (!ok && context.mounted) {
          showAppSnack(
            context,
            'Could not open Google Maps on this device.',
            isError: true,
          );
        }
      },
    );
  }
}

/// The primary action, anchored above the content rather than after it.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: child,
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13,
      color: AppColors.textSecondary,
      letterSpacing: 0.5,
    ),
  );
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.from, required this.to});
  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoutePoint(icon: Icons.trip_origin, label: from),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(width: 1, height: 18, color: AppColors.border),
          ),
          _RoutePoint(icon: Icons.place, label: to, isDestination: true),
        ],
      ),
    );
  }
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({
    required this.icon,
    required this.label,
    this.isDestination = false,
  });
  final IconData icon;
  final String label;
  final bool isDestination;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDestination ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final dt = ride.scheduledAt.toLocal();
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final dateStr =
        '${_monthAbbr(dt.month)} ${dt.day}, ${dt.year}  $h:$m $period';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _DetailChip(icon: Icons.schedule_outlined, label: dateStr),
        // Not a rupee. The fare is in taka, the label already carries ৳, and
        // Material ships no taka glyph — so the icon stays currency-neutral
        // rather than naming the wrong country's money.
        _DetailChip(
          icon: Icons.payments_outlined,
          label: '৳${ride.fare.toStringAsFixed(0)}',
        ),
        _DetailChip(
          icon: Icons.airline_seat_recline_normal_outlined,
          label:
              '${ride.seatsAvailable} seat${ride.seatsAvailable != 1 ? 's' : ''}',
        ),
        if (ride.genderPref == 'FEMALE_ONLY')
          _DetailChip(
            icon: Icons.female,
            label: 'Female only',
            color: AppColors.genderFemale,
          ),
        if (ride.genderPref == 'MALE_ONLY')
          _DetailChip(
            icon: Icons.male,
            label: 'Male only',
            color: AppColors.primary,
          ),
      ],
    );
  }

  String _monthAbbr(int m) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.segmentTrack,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: c)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) =>
      const SkeletonBox(width: 64, height: 14, borderRadius: 7);
}
