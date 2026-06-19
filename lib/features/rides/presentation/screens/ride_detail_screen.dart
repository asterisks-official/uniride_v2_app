import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/trust_score_ring.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/models/ride.dart';
import '../../domain/models/ride_request.dart';
import '../providers/my_rides_notifier.dart';

// Public so ride_requests_screen can invalidate after responding.
final rideDetailProvider =
    FutureProvider.autoDispose.family<Ride, String>((ref, rideId) {
  return ref.read(ridesRepositoryProvider).getRide(rideId);
});

class RideDetailScreen extends ConsumerStatefulWidget {
  const RideDetailScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends ConsumerState<RideDetailScreen> {
  bool _joining = false;
  RideRequest? _joinedRequest;
  bool _actioning = false;
  String? _error;

  // ── Passenger: request to join ─────────────────────────────────────────────

  Future<void> _requestJoin() async {
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final req =
          await ref.read(ridesRepositoryProvider).requestRide(widget.rideId);
      if (mounted) {
        setState(() {
          _joining = false;
          _joinedRequest = req;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request sent! The rider will respond shortly.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _joining = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
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

  Future<void> _startRide() => _riderAction(
      () => ref.read(ridesRepositoryProvider).startRide(widget.rideId));

  Future<void> _confirmRide() => _riderAction(
      () => ref.read(ridesRepositoryProvider).confirmRide(widget.rideId));

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel ride?'),
        content: const Text(
            'This will notify the passenger and the ride will be cancelled.'),
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
    final async = ref.watch(rideDetailProvider(widget.rideId));
    final auth = ref.watch(authNotifierProvider);
    final currentUserId = auth is Authenticated ? auth.user.id : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: async.when(
          loading: () => const _DetailLoadingView(),
          error: (e, _) => _DetailErrorView(
            message: e.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(rideDetailProvider(widget.rideId)),
          ),
          data: (ride) => _DetailView(
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
          ),
        ),
      ),
    );
  }
}

// ── Detail view (data loaded) ─────────────────────────────────────────────────

class _DetailView extends StatelessWidget {
  const _DetailView({
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

  bool get _isRider => currentUserId != null && currentUserId == ride.riderId;
  // The post owner manages the ride (and sees the waiting screen) regardless of
  // whether they posted as a driver (OFFER) or a passenger (REQUEST).
  bool get _isOwner => currentUserId != null && currentUserId == ride.creator.id;
  bool get _showWaiting => _isOwner && ride.status == 'SEARCHING';

  @override
  Widget build(BuildContext context) {
    if (_showWaiting) {
      return _WaitingView(
        ride: ride,
        actioning: actioning,
        error: error,
        onViewRequests: onViewRequests,
        onCancelRide: onCancelRide,
      );
    }

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        // ── Scrollable content ───────────────────────────────────────
        CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // Dark gradient hero with route
            SliverAppBar(
              expandedHeight: 210,
              pinned: true,
              backgroundColor: AppColors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Ride Details',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _RouteHero(ride: ride),
              ),
            ),

            // Body sections
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  16, 20, 16, 130 + bottomPad),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Status pill
                  _StatusBanner(status: ride.status),
                  const SizedBox(height: 16),

                  // Rider card
                  _RiderCard(ride: ride, isRider: _isRider),

                  // Passenger card (rider only, when matched)
                  if (_isRider && ride.passenger != null) ...[
                    const SizedBox(height: 12),
                    _PassengerCard(passenger: ride.passenger!),
                  ],

                  const SizedBox(height: 12),

                  // Trip details
                  _TripDetailsCard(ride: ride),

                  // Error banner
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: error!),
                  ],
                ]),
              ),
            ),
          ],
        ),

        // ── Sticky bottom CTA ────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _BottomCTA(
            ride: ride,
            isRider: _isRider,
            currentUserId: currentUserId,
            joining: joining,
            joinedRequest: joinedRequest,
            actioning: actioning,
            bottomPad: bottomPad,
            onJoin: onJoin,
            onViewRequests: onViewRequests,
            onStartRide: onStartRide,
            onCancelRide: onCancelRide,
            onConfirmRide: onConfirmRide,
          ),
        ),
      ],
    );
  }
}

// ── Waiting / searching view ─────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  const _WaitingView({
    required this.ride,
    required this.actioning,
    required this.error,
    required this.onViewRequests,
    required this.onCancelRide,
  });

  final Ride ride;
  final bool actioning;
  final String? error;
  final VoidCallback onViewRequests;
  final VoidCallback onCancelRide;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final pending = ride.pendingRequestCount ?? 0;
    final dt = ride.scheduledAt.toLocal();
    final timeStr = DateFormat('h:mm a').format(dt);
    final dateStr = DateFormat('EEE, MMM d').format(dt);

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: Column(
        children: [
          // ── Hero ─────────────────────────────────────────────────────
          _WaitingHero(height: size.height * 0.44),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 16),
              child: Column(
                children: [
                  const Text(
                    'Finding your\nmatch',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.lightTextPrimary,
                      letterSpacing: -0.8,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your ride is live. We\'ll notify you the moment a student requests to join.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: AppColors.lightTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  _WaitingRow(
                    icon: Icons.route_rounded,
                    iconColor: AppColors.primary,
                    iconBg: const Color(0xFFEAF7D9),
                    title: ride.originAddress,
                    subtitle: 'to ${ride.destAddress}',
                  ),
                  const SizedBox(height: 14),
                  _WaitingRow(
                    icon: Icons.payments_rounded,
                    iconColor: AppColors.secondary,
                    iconBg: const Color(0xFFDCFCE7),
                    title: '৳${ride.fare.toStringAsFixed(0)} · $timeStr',
                    subtitle: '$dateStr · 1 seat',
                  ),

                  if (pending > 0) ...[
                    const SizedBox(height: 14),
                    _PendingRow(count: pending, onTap: onViewRequests),
                  ],

                  if (error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(message: error!),
                  ],
                ],
              ),
            ),
          ),

          // ── Bottom actions ───────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad + 16),
            child: Row(
              children: [
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: actioning ? null : onCancelRide,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.lightTextPrimary,
                      side: const BorderSide(color: AppColors.lightBorder),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                    ),
                    child: actioning
                        ? const _Spinner(color: AppColors.lightTextSecondary)
                        : const Text('Cancel',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: onViewRequests,
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inbox_rounded, size: 19),
                          const SizedBox(width: 8),
                          Text(
                            pending > 0 ? 'Requests ($pending)' : 'View requests',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero with searching animation ────────────────────────────────────────────

class _WaitingHero extends StatelessWidget {
  const _WaitingHero({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDCF5BC), Color(0xFFEFFBE2), AppColors.lightSurface],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing rings behind the rider
          const _PulseRings(),

          // Rider animation
          Lottie.asset(
            'assets/animations/scooter.json',
            width: height * 0.66,
            height: height * 0.66,
            fit: BoxFit.contain,
            repeat: true,
          ),

          // Back button
          Positioned(
            top: topPad + 8,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: AppColors.lightTextPrimary),
              ),
            ),
          ),

          // "Searching" chip
          Positioned(
            bottom: 28,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _BlinkingDot(),
                  SizedBox(width: 8),
                  Text(
                    'Searching nearby',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Expanding concentric rings to convey active searching.
class _PulseRings extends StatefulWidget {
  const _PulseRings();

  @override
  State<_PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<_PulseRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: List.generate(3, (i) {
            final t = (_c.value + i / 3) % 1.0;
            return Opacity(
              opacity: (1.0 - t) * 0.35,
              child: Container(
                width: 120 + t * 200,
                height: 120 + t * 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// Small pulsing status dot.
class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// Reference-style list row: colorful rounded-square icon + title + subtitle.
class _WaitingRow extends StatelessWidget {
  const _WaitingRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightTextPrimary,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.lightTextSecondary,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Tappable pending-requests row.
class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded,
                  size: 22, color: AppColors.warning),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count pending request${count != 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Tap to review and accept',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 22, color: AppColors.warning),
          ],
        ),
      ),
    );
  }
}

// ── Route hero ────────────────────────────────────────────────────────────────

class _RouteHero extends StatelessWidget {
  const _RouteHero({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3020), AppColors.black],
        ),
      ),
      padding: EdgeInsets.fromLTRB(22, topPad + 56, 22, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Origin
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ride.originAddress,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Dashed connector
          Padding(
            padding: const EdgeInsets.only(left: 5.5),
            child: Column(
              children: List.generate(
                4,
                (_) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 2.5),
                  width: 1,
                  height: 5,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            ),
          ),
          // Destination
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.error, size: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ride.destAddress,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  (String, Color, IconData) get _meta => switch (status) {
        'SEARCHING' => ('Looking for passengers', AppColors.warning, Icons.search_rounded),
        'MATCHED' => ('Passenger matched', AppColors.primary, Icons.people_rounded),
        'IN_PROGRESS' => ('Ride in progress', const Color(0xFF6366F1), Icons.directions_car_rounded),
        'COMPLETED' => ('Ride completed', AppColors.secondary, Icons.check_circle_rounded),
        'CANCELLED' => ('Ride cancelled', AppColors.lightMuted, Icons.cancel_rounded),
        _ => ('Unknown status', AppColors.lightMuted, Icons.info_outline_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = _meta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rider card ────────────────────────────────────────────────────────────────

class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.ride, required this.isRider});
  final Ride ride;
  final bool isRider;

  @override
  Widget build(BuildContext context) {
    // Show the matched driver if present, otherwise the person who posted.
    final rider = ride.rider ?? ride.poster;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.lightSegmentTrack,
                backgroundImage: rider.profilePictureUrl != null
                    ? CachedNetworkImageProvider(rider.profilePictureUrl!)
                    : null,
                child: rider.profilePictureUrl == null
                    ? Text(
                        rider.name.isNotEmpty
                            ? rider.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 22,
                          color: AppColors.lightTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rider.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    if (isRider) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
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
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 3),
                    Text(
                      rider.averageRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                        width: 3,
                        height: 3,
                        decoration: const BoxDecoration(
                          color: AppColors.lightMuted,
                          shape: BoxShape.circle,
                        )),
                    const SizedBox(width: 8),
                    Text(
                      '${rider.ridesCompleted} rides',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TrustScoreRing(score: 50, size: 42),
        ],
      ),
    );
  }
}

// ── Passenger card ────────────────────────────────────────────────────────────

class _PassengerCard extends StatelessWidget {
  const _PassengerCard({required this.passenger});
  final PassengerSummary passenger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.lightSegmentTrack,
            backgroundImage: passenger.profilePictureUrl != null
                ? CachedNetworkImageProvider(passenger.profilePictureUrl!)
                : null,
            child: passenger.profilePictureUrl == null
                ? Text(
                    passenger.name.isNotEmpty
                        ? passenger.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Passenger',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  passenger.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Matched',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trip details card ─────────────────────────────────────────────────────────

class _TripDetailsCard extends StatelessWidget {
  const _TripDetailsCard({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final dt = ride.scheduledAt.toLocal();
    final h =
        dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final dateStr =
        '${_monthAbbr(dt.month)} ${dt.day}, ${dt.year}  $h:$m $period';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRIP DETAILS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.lightTextSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.schedule_outlined,
            label: 'Scheduled',
            value: dateStr,
          ),
          const _Divider(),
          _DetailRow(
            icon: Icons.payments_outlined,
            label: 'Fare per seat',
            value: '৳${ride.fare.toStringAsFixed(0)}',
            valueColor: AppColors.primary,
            valueBold: true,
          ),
          const _Divider(),
          _DetailRow(
            icon: Icons.airline_seat_recline_normal_outlined,
            label: 'Seats available',
            value:
                '${ride.seatsAvailable} seat${ride.seatsAvailable != 1 ? 's' : ''}',
          ),
          if (ride.genderPref != 'ANY') ...[
            const _Divider(),
            _DetailRow(
              icon: ride.genderPref == 'FEMALE_ONLY'
                  ? Icons.female_rounded
                  : Icons.male_rounded,
              label: 'Gender preference',
              value: ride.genderPref == 'FEMALE_ONLY'
                  ? 'Female only'
                  : 'Male only',
              valueColor: ride.genderPref == 'FEMALE_ONLY'
                  ? const Color(0xFFDB2777)
                  : AppColors.primary,
            ),
          ],
        ],
      ),
    );
  }

  String _monthAbbr(int m) => const [
        '',
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.lightSegmentTrack,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.lightTextSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.lightTextSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  valueBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        color: AppColors.lightBorder,
      );
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.20)),
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
}

// ── Sticky bottom CTA ─────────────────────────────────────────────────────────

class _BottomCTA extends StatelessWidget {
  const _BottomCTA({
    required this.ride,
    required this.isRider,
    required this.currentUserId,
    required this.joining,
    required this.joinedRequest,
    required this.actioning,
    required this.bottomPad,
    required this.onJoin,
    required this.onViewRequests,
    required this.onStartRide,
    required this.onCancelRide,
    required this.onConfirmRide,
  });

  final Ride ride;
  final bool isRider;
  final String? currentUserId;
  final bool joining;
  final RideRequest? joinedRequest;
  final bool actioning;
  final double bottomPad;
  final VoidCallback onJoin;
  final VoidCallback onViewRequests;
  final VoidCallback onStartRide;
  final VoidCallback onCancelRide;
  final VoidCallback onConfirmRide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.lightBackground.withValues(alpha: 0),
            AppColors.lightBackground,
          ],
          stops: const [0.0, 0.35],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPad + 16),
      child: isRider
          ? _RiderActions(
              ride: ride,
              actioning: actioning,
              onViewRequests: onViewRequests,
              onStartRide: onStartRide,
              onCancelRide: onCancelRide,
              onConfirmRide: onConfirmRide,
            )
          : _PassengerActions(
              ride: ride,
              currentUserId: currentUserId,
              joining: joining,
              joinedRequest: joinedRequest,
              actioning: actioning,
              onJoin: onJoin,
              onConfirm: onConfirmRide,
            ),
    );
  }
}

// ── Rider actions ─────────────────────────────────────────────────────────────

class _RiderActions extends StatelessWidget {
  const _RiderActions({
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
            ElevatedButton.icon(
              icon: const Icon(Icons.people_outline_rounded),
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.directions_car_rounded),
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
        return ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline_rounded),
          label: actioning
              ? const _Spinner(color: Colors.white)
              : const Text('Confirm Completion'),
          onPressed: actioning ? null : onConfirmRide,
        );

      case 'COMPLETED':
        return _FinalStatusChip(
          label: 'Ride completed',
          color: AppColors.secondary,
          icon: Icons.check_circle_rounded,
        );

      case 'CANCELLED':
        return _FinalStatusChip(
          label: 'Ride cancelled',
          color: AppColors.lightMuted,
          icon: Icons.cancel_rounded,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Passenger actions ─────────────────────────────────────────────────────────

class _PassengerActions extends StatelessWidget {
  const _PassengerActions({
    required this.ride,
    required this.currentUserId,
    required this.joining,
    required this.joinedRequest,
    required this.actioning,
    required this.onJoin,
    required this.onConfirm,
  });

  final Ride ride;
  final String? currentUserId;
  final bool joining;
  final RideRequest? joinedRequest;
  final bool actioning;
  final VoidCallback onJoin;
  final VoidCallback onConfirm;

  bool get _isPassenger =>
      currentUserId != null && ride.passenger?.id == currentUserId;

  @override
  Widget build(BuildContext context) {
    if (joinedRequest != null) {
      return _FinalStatusChip(
        label: 'Request sent — waiting for rider',
        color: AppColors.primary,
        icon: Icons.hourglass_top_rounded,
      );
    }

    // On a REQUEST post the viewer is a driver offering to fulfil it; on an
    // OFFER post the viewer is a passenger asking to join.
    final isRequestPost = ride.type == 'REQUEST';

    switch (ride.status) {
      case 'SEARCHING':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: Icon(isRequestPost
                ? Icons.directions_bike_rounded
                : Icons.hail_rounded),
            label: joining
                ? const _Spinner(color: Colors.white)
                : Text(isRequestPost ? 'Offer to Drive' : 'Request to Join'),
            onPressed: joining ? null : onJoin,
          ),
        );

      case 'MATCHED':
        if (_isPassenger) {
          return _FinalStatusChip(
            label: "You're matched! Waiting for rider to start.",
            color: AppColors.primary,
            icon: Icons.people_rounded,
          );
        }
        return _FinalStatusChip(
          label: 'Ride is matched',
          color: AppColors.lightMuted,
          icon: Icons.lock_outline_rounded,
        );

      case 'IN_PROGRESS':
        if (_isPassenger) {
          return ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: actioning
                ? const _Spinner(color: Colors.white)
                : const Text('Confirm Completion'),
            onPressed: actioning ? null : onConfirm,
          );
        }
        return _FinalStatusChip(
          label: 'Ride in progress',
          color: const Color(0xFF6366F1),
          icon: Icons.directions_car_rounded,
        );

      case 'COMPLETED':
        return _FinalStatusChip(
          label: 'Ride completed',
          color: AppColors.secondary,
          icon: Icons.check_circle_rounded,
        );

      case 'CANCELLED':
        return _FinalStatusChip(
          label: 'Ride cancelled',
          color: AppColors.lightMuted,
          icon: Icons.cancel_rounded,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── Final status chip (terminal states) ───────────────────────────────────────

class _FinalStatusChip extends StatelessWidget {
  const _FinalStatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small spinner for button loading states ───────────────────────────────────

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color,
        ),
      );
}

// ── Loading state ─────────────────────────────────────────────────────────────

class _DetailLoadingView extends StatelessWidget {
  const _DetailLoadingView();

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Container(
          height: 210 + topPad,
          color: AppColors.black,
          child: Center(
            child: CircularProgressIndicator(
              color: Colors.white.withValues(alpha: 0.6),
              strokeWidth: 2,
            ),
          ),
        ),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _DetailErrorView extends StatelessWidget {
  const _DetailErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: Colors.white,
        title: const Text('Ride Details'),
      ),
      body: ErrorRetry(message: message, onRetry: onRetry),
    );
  }
}
