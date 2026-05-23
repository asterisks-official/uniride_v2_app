import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/rides/domain/models/ride.dart';
import 'trust_score_ring.dart';

class RideCard extends StatelessWidget {
  const RideCard({super.key, required this.ride, this.onTap});

  final Ride ride;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RiderRow(ride: ride),
              const SizedBox(height: 12),
              _RouteRow(ride: ride),
              const SizedBox(height: 6),
              _DetailsRow(ride: ride),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiderRow extends StatelessWidget {
  const _RiderRow({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final rider = ride.rider;
    final avatar = rider.profilePictureUrl;
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.segmentTrack,
          backgroundImage:
              avatar != null ? CachedNetworkImageProvider(avatar) : null,
          child: avatar == null
              ? Text(
                  rider.name.isNotEmpty ? rider.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            rider.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Icon(Icons.star_rounded, size: 15, color: AppColors.warning),
        const SizedBox(width: 2),
        Text(
          rider.averageRating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(width: 10),
        // trustScore is not in the feed — default to 50.
        TrustScoreRing(score: 50, size: 32),
      ],
    );
  }
}

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${ride.originAddress}  →  ${ride.destAddress}',
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (ride.genderPref == 'FEMALE_ONLY') ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFCE7F3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Female only',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFDB2777),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final seats = ride.seatsAvailable;
    return Text(
      '${_formatTime(ride.scheduledAt)} · ৳${ride.fare.toStringAsFixed(0)} · $seats seat${seats != 1 ? 's' : ''}',
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isTomorrow =
        dt.year == now.year && dt.month == now.month && dt.day == now.day + 1;
    final time = '$h:$m $period';
    if (isToday) return 'Today $time';
    if (isTomorrow) return 'Tomorrow $time';
    return '${dt.day}/${dt.month} $time';
  }
}
