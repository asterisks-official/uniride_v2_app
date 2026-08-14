import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/rides/domain/models/ride.dart';

/// Feed card for a single ride.
///
/// Hierarchy is ordered by what a commuter actually decides on: departure time
/// and fare lead, the route reads as a journey rather than an ellipsised
/// "A → B" string, and the driver sits underneath as supporting trust
/// information.
class RideCard extends StatefulWidget {
  const RideCard({super.key, required this.ride, this.onTap});

  final Ride ride;
  final VoidCallback? onTap;

  @override
  State<RideCard> createState() => _RideCardState();
}

class _RideCardState extends State<RideCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final ride = widget.ride;
    final femaleOnly = ride.genderPref == 'FEMALE_ONLY';

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.977 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            // A soft shadow rather than a hard 1px border — the border was the
            // main reason the old feed read as a stack of boxes.
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.03),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeadRow(ride: ride, femaleOnly: femaleOnly),
              const SizedBox(height: 14),
              _RouteTimeline(ride: ride),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              const SizedBox(height: 12),
              _DriverRow(ride: ride),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Time + fare ──────────────────────────────────────────────────────────────

class _HeadRow extends StatelessWidget {
  const _HeadRow({required this.ride, required this.femaleOnly});

  final Ride ride;
  final bool femaleOnly;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dayLabel(ride.scheduledAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.01,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _timeLabel(ride.scheduledAt),
                style: const TextStyle(
                  fontSize: 19,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '৳${ride.fare.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 21,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 3),
            if (femaleOnly)
              const _Badge(
                text: 'Female only',
                fg: AppColors.genderFemale,
                bg: AppColors.genderFemaleWash,
              )
            else
              Text(
                'per seat',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    if (diff > 1 && diff < 7) return days[dt.weekday - 1];
    return '${dt.day}/${dt.month}';
  }

  static String _timeLabel(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }
}

// ── Route ────────────────────────────────────────────────────────────────────

/// Origin and destination each get their own line, joined by a rail. The old
/// single-line "origin → destination" ellipsised away the destination on almost
/// every real Dhaka address.
class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 12,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.muted, width: 1.8),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: AppColors.border,
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ride.originAddress,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  ride.destAddress,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
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

// ── Driver ───────────────────────────────────────────────────────────────────

class _DriverRow extends StatelessWidget {
  const _DriverRow({required this.ride});

  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final rider = ride.rider;
    final avatar = rider.profilePictureUrl;
    final seats = ride.seatsAvailable;

    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: AppColors.primaryWash,
          backgroundImage:
              avatar != null ? CachedNetworkImageProvider(avatar) : null,
          child: avatar == null
              ? Text(
                  rider.name.isNotEmpty ? rider.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            rider.name,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 7),
        const Icon(Icons.star_rounded, size: 14, color: AppColors.warning),
        const SizedBox(width: 1),
        Text(
          rider.averageRating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        _Badge(
          text: '$seats seat${seats != 1 ? 's' : ''}',
          fg: AppColors.primary,
          bg: AppColors.primaryWash,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.fg, required this.bg});

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          color: fg,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.05,
        ),
      ),
    );
  }
}
