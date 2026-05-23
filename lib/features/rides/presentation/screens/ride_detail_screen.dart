import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton.dart';
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
    setState(() { _joining = true; _error = null; });
    try {
      final req = await ref
          .read(ridesRepositoryProvider)
          .requestRide(widget.rideId);
      if (mounted) {
        setState(() { _joining = false; _joinedRequest = req; });
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
    setState(() { _actioning = true; _error = null; });
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

  Future<void> _startRide() =>
      _riderAction(() => ref.read(ridesRepositoryProvider).startRide(widget.rideId));

  Future<void> _confirmRide() =>
      _riderAction(() => ref.read(ridesRepositoryProvider).confirmRide(widget.rideId));

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel ride?'),
        content: const Text('This will notify the passenger and the ride will be cancelled.'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Details')),
      body: async.when(
        loading: () => const RideDetailSkeleton(),
        error: (e, _) => ErrorRetry(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(rideDetailProvider(widget.rideId)),
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
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _RideDetailBody extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rider = ride.rider;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Rider card ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.segmentTrack,
                  backgroundImage: rider.profilePictureUrl != null
                      ? CachedNetworkImageProvider(rider.profilePictureUrl!)
                      : null,
                  child: rider.profilePictureUrl == null
                      ? Text(
                          rider.name.isNotEmpty
                              ? rider.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
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
                          Text(
                            rider.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_isRider) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2,
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
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 3),
                          Text(
                            '${rider.averageRating.toStringAsFixed(1)} · ${rider.ridesCompleted} rides',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TrustScoreRing(score: 50, size: 40),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Passenger card (only when matched, shown to rider) ──────────────
          if (_isRider && ride.passenger != null) ...[
            _SectionTitle(label: 'Passenger'),
            const SizedBox(height: 10),
            _PassengerCard(passenger: ride.passenger!),
            const SizedBox(height: 20),
          ],

          // ── Route ───────────────────────────────────────────────────────────
          _SectionTitle(label: 'Route'),
          const SizedBox(height: 10),
          _RouteRow(from: ride.originAddress, to: ride.destAddress),
          const SizedBox(height: 20),

          // ── Details ─────────────────────────────────────────────────────────
          _SectionTitle(label: 'Details'),
          const SizedBox(height: 10),
          _DetailGrid(ride: ride),
          const SizedBox(height: 28),

          // ── Error banner ────────────────────────────────────────────────────
          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── CTA ─────────────────────────────────────────────────────────────
          if (_isRider)
            _RiderCTA(
              ride: ride,
              actioning: actioning,
              onViewRequests: onViewRequests,
              onStartRide: onStartRide,
              onCancelRide: onCancelRide,
              onConfirmRide: onConfirmRide,
            )
          else
            _PassengerCTA(
              ride: ride,
              currentUserId: currentUserId,
              joining: joining,
              joinedRequest: joinedRequest,
              onJoin: onJoin,
              onConfirm: onConfirmRide,
              actioning: actioning,
            ),
          const SizedBox(height: 16),
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
        return ElevatedButton(
          onPressed: actioning ? null : onConfirmRide,
          child: actioning
              ? const _Spinner(color: Colors.white)
              : const Text('Confirm Completion'),
        );

      case 'COMPLETED':
        return const _StatusChip(
          label: 'Ride completed',
          color: AppColors.secondary,
        );

      case 'CANCELLED':
        return const _StatusChip(label: 'Ride cancelled', color: AppColors.muted);

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
    required this.actioning,
  });

  final Ride ride;
  final String? currentUserId;
  final bool joining;
  final RideRequest? joinedRequest;
  final VoidCallback onJoin;
  final VoidCallback onConfirm;
  final bool actioning;

  bool get _isPassenger =>
      currentUserId != null && ride.passenger?.id == currentUserId;

  @override
  Widget build(BuildContext context) {
    if (joinedRequest != null) {
      return const _StatusChip(
        label: 'Request sent',
        color: AppColors.secondary,
      );
    }

    switch (ride.status) {
      case 'SEARCHING':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: joining ? null : onJoin,
            child: joining
                ? const _Spinner(color: Colors.white)
                : const Text('Request to Join'),
          ),
        );

      case 'MATCHED':
        if (_isPassenger) {
          return const _StatusChip(
            label: 'You\'re matched! Waiting for rider to start.',
            color: AppColors.secondary,
          );
        }
        return const _StatusChip(label: 'Ride matched', color: AppColors.muted);

      case 'IN_PROGRESS':
        if (_isPassenger) {
          return ElevatedButton(
            onPressed: actioning ? null : onConfirm,
            child: actioning
                ? const _Spinner(color: Colors.white)
                : const Text('Confirm Completion'),
          );
        }
        return const _StatusChip(label: 'Ride in progress', color: AppColors.muted);

      case 'COMPLETED':
        return const _StatusChip(
          label: 'Ride completed',
          color: AppColors.secondary,
        );

      case 'CANCELLED':
        return const _StatusChip(label: 'Ride cancelled', color: AppColors.muted);

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
          _RoutePoint(
              icon: Icons.place, label: to, isDestination: true),
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
          color:
              isDestination ? AppColors.primary : AppColors.textSecondary,
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
        _DetailChip(
          icon: Icons.currency_rupee_outlined,
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
            color: const Color(0xFFDB2777),
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
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
