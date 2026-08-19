import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/motion.dart';
import '../../../../shared/widgets/uni_loader.dart';
import '../../domain/models/ride.dart';
import '../providers/compose_ride_notifier.dart' show rideQuoteProvider;
import '../providers/my_rides_notifier.dart';
import '../providers/rides_feed_notifier.dart';
import '../widgets/trip_map.dart';
import 'ride_detail_screen.dart' show rideDetailProvider;

/// Where a freshly posted trip waits for the other side.
///
/// Map above, state below — the arrangement every ride app converges on,
/// because the trip is the subject and its status is commentary on it. While
/// the ride is open the route carries a travelling light: the screen's way of
/// saying this is being shown to people right now. It stops the moment the
/// ride has an answer.
///
/// Replaces the compose route on success, so back cannot return to a filled-in
/// form that would post a duplicate. Nobody is trapped here — the post stays
/// live whether or not anyone is looking at it, and the cancel that ends the
/// wait lives on this screen because this is where the waiting happens.
class RideWaitingScreen extends ConsumerStatefulWidget {
  const RideWaitingScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideWaitingScreen> createState() => _RideWaitingScreenState();
}

class _RideWaitingScreenState extends ConsumerState<RideWaitingScreen> {
  Timer? _poll;
  Timer? _tick;
  bool _cancelling = false;

  /// Push isn't wired into the app yet, so the screen asks. Slow enough to be
  /// polite to the server, fast enough that an accept feels noticed.
  static const _pollEvery = Duration(seconds: 6);

  /// How long an INSTANT post keeps searching before the server expires it.
  /// Mirrors `INSTANT_SEARCH_WINDOW_MS` in the backend's rides service — the
  /// countdown is a promise about server behaviour, so the two must agree.
  static const instantWindow = Duration(minutes: 30);

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(_pollEvery, (_) {
      if (mounted) ref.invalidate(rideDetailProvider(widget.rideId));
    });
    // Drives the elapsed/remaining readout. A wait with no visible progress is
    // where people start assuming the app has stalled — the one thing this
    // screen exists to prevent.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTimers() {
    _poll?.cancel();
    _tick?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _cancel(Ride ride) async {
    final isRequest = ride.isRequest;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRequest ? 'Cancel this request?' : 'Cancel this ride?'),
        content: Text(
          isRequest
              ? 'It comes off the feed and riders will no longer see it.'
              : 'It comes off the feed, and anyone who asked to join '
                    'is notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref.read(ridesRepositoryProvider).cancelRide(ride.id);
      if (!mounted) return;
      ref.invalidate(myRidesProvider);
      ref.invalidate(ridesFeedProvider);
      showAppSnack(
        context,
        isRequest ? 'Request cancelled.' : 'Ride cancelled.',
      );
      context.go('/home');
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        showAppSnack(context, e.message, isError: true);
      }
    }
  }

  Future<void> _viewRequests() async {
    await context.push('/rides/${widget.rideId}/requests');
    if (mounted) ref.invalidate(rideDetailProvider(widget.rideId));
  }

  /// The road between the ends, if the server can draw one.
  ///
  /// Reuses the quote the compose screen already asked for — same pair of
  /// points, same cached answer — so the route usually appears on the first
  /// frame. A failure is not an error state here: [TripMap] falls back to a
  /// dotted straight line, which is honest about being an approximation.
  List<LatLng> _routeFor(Ride ride) {
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
  Widget build(BuildContext context) {
    // The wait ends server-side; notice it here. Polling stops for good — a
    // matched or cancelled ride never un-happens back into SEARCHING.
    ref.listen(rideDetailProvider(widget.rideId), (prev, next) {
      final status = next.asData?.value.status;
      if (status == null || status == 'SEARCHING') return;
      _stopTimers();
      if (prev?.asData?.value.status == 'SEARCHING' && status == 'MATCHED') {
        HapticFeedback.mediumImpact();
      }
    });

    final async = ref.watch(rideDetailProvider(widget.rideId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const Center(child: UniLoader(size: 44)),
        error: (e, _) => SafeArea(
          child: ErrorRetry(
            message: e.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(rideDetailProvider(widget.rideId)),
          ),
        ),
        data: _buildTrip,
      ),
    );
  }

  Widget _buildTrip(Ride ride) {
    final searching = ride.status == 'SEARCHING';

    final sheet = switch (ride.status) {
      'SEARCHING' => _WaitingSheet(
        ride: ride,
        cancelling: _cancelling,
        onCancel: () => _cancel(ride),
        onViewRequests: _viewRequests,
      ),
      'CANCELLED' => _ClosedSheet(
        icon: Icons.block_rounded,
        tint: AppColors.muted,
        headline: ride.isRequest
            ? 'This request was cancelled'
            : 'This ride was cancelled',
        detail: 'Nothing was charged, and nobody was matched.',
        primary: null,
        onLeave: _leave,
      ),
      'EXPIRED' => _ClosedSheet(
        icon: Icons.hourglass_bottom_rounded,
        tint: AppColors.warning,
        headline: ride.isRequest ? 'No rider found' : 'No one joined this time',
        detail: ride.isRequest
            ? 'Your request expired before a rider took it. Try again, or '
                  'post it for a later time.'
            : 'Your ride expired without a passenger. Post it again when '
                  "you're ready to go.",
        primary: (
          'Post again',
          Icons.refresh_rounded,
          () => context.pushReplacement('/rides/create'),
        ),
        onLeave: _leave,
      ),
      _ => _MatchedSheet(ride: ride),
    };

    // A ride with no usable coordinates predates the two-point compose screen.
    // Rather than framing a map on the Gulf of Guinea, the sheet takes the
    // whole screen — which is exactly what it did before the map existed.
    if (!ride.hasRoute) {
      return SafeArea(
        child: Column(
          children: [
            _TopBar(onClose: _leave),
            Expanded(child: sheet),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              flex: 43,
              child: TripMap(
                origin: LatLng(ride.originLat!, ride.originLng!),
                destination: LatLng(ride.destLat!, ride.destLng!),
                route: _routeFor(ride),
                pulse: searching,
                // Generous at the bottom: the sheet's rounded top overlaps the
                // map, and a pin tucked under it cannot be seen.
                padding: const EdgeInsets.fromLTRB(44, 74, 44, 52),
              ),
            ),
            Expanded(flex: 57, child: _SheetShell(child: sheet)),
          ],
        ),
        SafeArea(child: _TopBar(onClose: _leave, floating: true)),
      ],
    );
  }
}

// ── Chrome ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, this.floating = false});

  final VoidCallback onClose;

  /// Over the map, where the button needs its own surface to stay legible.
  final bool floating;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: PressableScale(
        scale: 0.93,
        onTap: onClose,
        child: Container(
          height: 42,
          width: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: floating ? AppColors.surface : Colors.transparent,
            shape: BoxShape.circle,
            boxShadow: floating
                ? [
                    BoxShadow(
                      color: AppColors.dark.withValues(alpha: 0.16),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 21,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    ),
  );
}

/// The panel the status lives in, riding over the bottom of the map.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      boxShadow: [
        BoxShadow(
          color: AppColors.dark.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, -8),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(top: 9, bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.muted.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

// ── Waiting ──────────────────────────────────────────────────────────────────

class _WaitingSheet extends StatelessWidget {
  const _WaitingSheet({
    required this.ride,
    required this.cancelling,
    required this.onCancel,
    required this.onViewRequests,
  });

  final Ride ride;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onViewRequests;

  @override
  Widget build(BuildContext context) {
    final (headline, sub) = switch ((ride.isRequest, ride.isInstant)) {
      (false, true) => (
        'Your ride is live',
        'Passengers nearby can see it now. '
            'Anyone who asks to join appears here.',
      ),
      (false, false) => (
        'Your ride is posted',
        'Passengers heading your way can find it and ask to join.',
      ),
      (true, true) => (
        'Finding you a rider',
        'Riders nearby can see your trip. The first to take it gets in touch.',
      ),
      (true, false) => (
        'Your request is posted',
        'Riders heading your way can take it any time before you leave.',
      ),
    };

    final pending = ride.pendingRequestCount ?? 0;
    final now = DateTime.now();

    // The deadline the server actually enforces: 30 minutes for an instant
    // post, departure time for a scheduled one. Same rule as `expiryDelayMs`
    // in the backend, so the countdown cannot promise time the ride will not
    // get.
    final expiry = ride.isInstant
        ? ride.createdAt.add(_RideWaitingScreenState.instantWindow)
        : ride.scheduledAt;
    final total = expiry.difference(ride.createdAt);
    final remaining = expiry.difference(now);

    // A bar only where it means something. Over a 30-minute window it is a
    // real percent-done indicator; over a window of days it would be a
    // stationary line pretending to be one.
    final progress = ride.isInstant && total.inSeconds > 0
        ? (remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0)
        : null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            children: [
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              _StatusStrip(
                elapsed: _elapsedLabel(now.difference(ride.createdAt)),
                remaining: ride.isInstant ? _remainingLabel(remaining) : null,
              ),

              if (progress != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    // Determinate: the one thing a looping bar cannot say is
                    // how much of the window is left, which is the only real
                    // progress this screen has.
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppColors.primaryWash,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              FadeSlideIn(child: _TripCard(ride: ride)),

              if (pending > 0) ...[
                const SizedBox(height: 12),
                FadeSlideIn(
                  child: _RequestsBanner(
                    count: pending,
                    isRequest: ride.isRequest,
                    onTap: onViewRequests,
                  ),
                ),
              ],
            ],
          ),
        ),

        // The wait needs no button of its own — the X leaves, and the post
        // survives it. So the bar carries only the action that undoes it, at
        // its true weight: a line of text, not a slab of red.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Closing this screen keeps it posted.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              TextButton(
                onPressed: cancelling ? null : onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size.fromHeight(42),
                ),
                child: cancelling
                    ? const UniDots(color: AppColors.error)
                    : Text(
                        ride.isRequest ? 'Cancel request' : 'Cancel ride',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _elapsedLabel(Duration d) {
    if (d.isNegative || d.inSeconds < 45) return 'Posted just now';
    if (d.inMinutes < 60) return 'Posted ${d.inMinutes} min ago';
    final h = d.inHours;
    return h == 1 ? 'Posted an hour ago' : 'Posted $h hours ago';
  }

  static String _remainingLabel(Duration d) {
    if (d.isNegative || d.inSeconds <= 0) return 'Expiring';
    if (d.inMinutes < 1) return 'Under a minute left';
    return '${d.inMinutes + 1} min left';
  }
}

/// The two moving facts about a wait: how long it has run, and how long it
/// has left. Kept on one line so neither reads as an alarm.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.elapsed, this.remaining});

  final String elapsed;
  final String? remaining;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.schedule_rounded,
          size: 14,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            elapsed,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        if (remaining != null) ...[
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
          ),
          Flexible(
            child: Text(
              remaining!,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Someone answered. The only thing on this screen that is genuinely news, so
/// it is the only thing wearing the brand colour at full strength.
class _RequestsBanner extends StatelessWidget {
  const _RequestsBanner({
    required this.count,
    required this.isRequest,
    required this.onTap,
  });

  final int count;
  final bool isRequest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = count == 1 ? '' : 's';
    final who = isRequest ? 'rider$s' : 'passenger$s';
    final verb = isRequest ? 'offered to take this' : 'asked to join';

    return PressableScale(
      scale: 0.99,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: AppColors.primaryWash,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              height: 32,
              width: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count $who $verb',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 21,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Matched ──────────────────────────────────────────────────────────────────

class _MatchedSheet extends StatelessWidget {
  const _MatchedSheet({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    // A REQUEST is fulfilled by a rider, an OFFER by a passenger.
    final other = ride.isRequest ? ride.rider?.name : ride.passenger?.name;

    final (headline, sub) = switch (ride.status) {
      'MATCHED' => (
        "You're matched!",
        other == null
            ? 'Open the ride to coordinate the pickup.'
            : '$other is in. Open the ride to coordinate the pickup.',
      ),
      'IN_PROGRESS' => ('Ride in progress', 'Open the ride to follow along.'),
      _ => ('Ride completed', 'Open the ride to see the details.'),
    };

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            children: [
              Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 26,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          sub,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.35,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _TripCard(ride: ride),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: AppButton(
            label: 'View ride',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => context.pushReplacement('/rides/${ride.id}'),
          ),
        ),
      ],
    );
  }
}

// ── Cancelled / expired ──────────────────────────────────────────────────────

class _ClosedSheet extends StatelessWidget {
  const _ClosedSheet({
    required this.icon,
    required this.tint,
    required this.headline,
    required this.detail,
    required this.primary,
    required this.onLeave,
  });

  final IconData icon;
  final Color tint;
  final String headline;
  final String detail;

  /// Label, icon and action for the one thing worth doing next, when there is
  /// one. A cancelled ride has nothing to offer; an expired one has "again".
  final (String, IconData, VoidCallback)? primary;

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            children: [
              Row(
                children: [
                  Container(
                    height: 46,
                    width: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tint.withValues(alpha: 0.12),
                    ),
                    child: Icon(icon, size: 24, color: tint),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      headline,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (primary case (final label, final icon, final onTap)) ...[
                AppButton(label: label, icon: icon, onPressed: onTap),
                const SizedBox(height: 8),
              ],
              AppButton(
                label: 'Back to Home',
                variant: AppButtonVariant.outline,
                onPressed: onLeave,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Trip summary ─────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  const _TripCard({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final when = ride.isInstant
        ? 'Now'
        : DateFormat('E h:mm a').format(ride.scheduledAt.toLocal());

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EndpointRow(
            icon: Icons.trip_origin,
            label: ride.originAddress,
            color: AppColors.textSecondary,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(width: 1, height: 14, color: AppColors.border),
          ),
          _EndpointRow(
            icon: Icons.place,
            label: ride.destAddress,
            color: AppColors.primary,
          ),
          const SizedBox(height: 13),
          // Wrap, not a Row: three chips and a long date do not fit one line
          // on a narrow phone, and a fare running off the edge is worse than
          // one sitting on a second row.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: ride.isInstant
                    ? Icons.bolt_rounded
                    : Icons.schedule_outlined,
                label: when,
              ),
              _InfoChip(
                icon: Icons.payments_outlined,
                label: '৳${ride.fare.toStringAsFixed(0)}',
              ),
              if (ride.genderPref == 'FEMALE_ONLY')
                const _InfoChip(
                  icon: Icons.shield_outlined,
                  label: 'Women only',
                  color: AppColors.genderFemale,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EndpointRow extends StatelessWidget {
  const _EndpointRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}
