import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/rides/domain/models/ride.dart';

class RideCard extends StatefulWidget {
  const RideCard({super.key, required this.ride, this.onTap});

  final Ride ride;
  final VoidCallback? onTap;

  @override
  State<RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<RideCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    value: 1.0,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.animateTo(0.0),
      onTapUp: (_) {
        _ctrl.animateTo(1.0);
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.animateTo(1.0),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: 0.97 + 0.03 * _ctrl.value,
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Rider header ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Row(
                  children: [
                    _CardAvatar(rider: widget.ride.rider),
                    const SizedBox(width: 10),
                    Expanded(child: _CardRiderMeta(rider: widget.ride.rider)),
                    const SizedBox(width: 8),
                    _CardTimePill(scheduledAt: widget.ride.scheduledAt),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Route block ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _CardRouteBlock(ride: widget.ride),
              ),
              const SizedBox(height: 12),

              // ── Bottom bar ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '৳${widget.ride.fare.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        'per seat',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.lightMuted,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _SeatsBadge(seats: widget.ride.seatsAvailable),
                    if (widget.ride.genderPref != 'ANY') ...[
                      const SizedBox(width: 6),
                      _GenderBadge(pref: widget.ride.genderPref),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _CardAvatar extends StatelessWidget {
  const _CardAvatar({required this.rider});
  final RiderSummary rider;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.lightSegmentTrack,
          backgroundImage: rider.profilePictureUrl != null
              ? CachedNetworkImageProvider(rider.profilePictureUrl!)
              : null,
          child: rider.profilePictureUrl == null
              ? Text(
                  rider.name.isNotEmpty ? rider.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                )
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Rider meta ────────────────────────────────────────────────────────────────

class _CardRiderMeta extends StatelessWidget {
  const _CardRiderMeta({required this.rider});
  final RiderSummary rider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rider.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.lightTextPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 13, color: AppColors.warning),
            const SizedBox(width: 3),
            Text(
              '${rider.averageRating.toStringAsFixed(1)}  ·  ${rider.ridesCompleted} trips',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Time pill ─────────────────────────────────────────────────────────────────

class _CardTimePill extends StatelessWidget {
  const _CardTimePill({required this.scheduledAt});
  final DateTime scheduledAt;

  String get _dayLabel {
    final dt = scheduledAt.toLocal();
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isTomorrow =
        dt.year == now.year && dt.month == now.month && dt.day == now.day + 1;
    if (isToday) return 'Today';
    if (isTomorrow) return 'Tmrw';
    return '${dt.day}/${dt.month}';
  }

  String get _timeLabel {
    final dt = scheduledAt.toLocal();
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _dayLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            _timeLabel,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Route block ───────────────────────────────────────────────────────────────

class _CardRouteBlock extends StatelessWidget {
  const _CardRouteBlock({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lightBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 1.5,
                  height: 24,
                  color: AppColors.lightBorder,
                ),
                const Icon(
                  Icons.location_on_rounded,
                  size: 13,
                  color: AppColors.error,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Addresses
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.originAddress,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Text(
                  ride.destAddress,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.lightTextSecondary,
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

// ── Seats badge ───────────────────────────────────────────────────────────────

class _SeatsBadge extends StatelessWidget {
  const _SeatsBadge({required this.seats});
  final int seats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.lightSegmentTrack,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_seat_rounded,
              size: 12, color: AppColors.lightTextSecondary),
          const SizedBox(width: 4),
          Text(
            '$seats seat${seats != 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gender badge ──────────────────────────────────────────────────────────────

class _GenderBadge extends StatelessWidget {
  const _GenderBadge({required this.pref});
  final String pref;

  @override
  Widget build(BuildContext context) {
    final isFemale = pref == 'FEMALE_ONLY';
    final color = isFemale ? const Color(0xFFDB2777) : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFemale ? Icons.female_rounded : Icons.male_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            isFemale ? 'Female' : 'Male',
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
