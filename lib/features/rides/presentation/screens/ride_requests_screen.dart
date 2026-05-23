import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../domain/models/ride_request.dart';

final rideRequestsProvider =
    FutureProvider.autoDispose.family<List<RideRequest>, String>((ref, rideId) {
  return ref.read(ridesRepositoryProvider).getRideRequests(rideId);
});

class RideRequestsScreen extends ConsumerStatefulWidget {
  const RideRequestsScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RideRequestsScreen> createState() => _RideRequestsScreenState();
}

class _RideRequestsScreenState extends ConsumerState<RideRequestsScreen> {
  // Track which request is being processed to prevent double-taps.
  final Set<String> _processing = {};
  String? _error;

  Future<void> _respond(String requestId, String action) async {
    if (_processing.contains(requestId)) return;
    setState(() { _processing.add(requestId); _error = null; });

    try {
      await ref
          .read(ridesRepositoryProvider)
          .respondToRequest(widget.rideId, requestId, action);

      if (mounted) {
        // Refresh the requests list.
        ref.invalidate(rideRequestsProvider(widget.rideId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'ACCEPT'
                  ? 'Request accepted — ride is now matched!'
                  : 'Request declined.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing.remove(requestId);
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rideRequestsProvider(widget.rideId));
    return Scaffold(
      appBar: AppBar(title: const Text('Join Requests')),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error, fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: async.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                itemBuilder: (_, _) => const RequestCardSkeleton(),
              ),
              error: (e, _) => ErrorRetry(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () =>
                    ref.invalidate(rideRequestsProvider(widget.rideId)),
              ),
              data: (requests) => requests.isEmpty
                  ? const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No pending requests',
                      subtitle: 'New requests will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.invalidate(rideRequestsProvider(widget.rideId)),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: requests.length,
                        itemBuilder: (context, i) => _RequestCard(
                          request: requests[i],
                          isProcessing: _processing.contains(requests[i].id),
                          onAccept: () => _respond(requests[i].id, 'ACCEPT'),
                          onDecline: () => _respond(requests[i].id, 'DECLINE'),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isProcessing,
    required this.onAccept,
    required this.onDecline,
  });

  final RideRequest request;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final passenger = request.passenger;
    final name = passenger?.name ?? 'Passenger';
    final avatar = passenger?.profilePictureUrl;
    final rating = passenger?.averageRating ?? 0.0;
    final rides = passenger?.ridesCompleted ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.segmentTrack,
                backgroundImage:
                    avatar != null ? CachedNetworkImageProvider(avatar) : null,
                child: avatar == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
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
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 13, color: AppColors.warning),
                        const SizedBox(width: 3),
                        Text(
                          '${rating.toStringAsFixed(1)} · $rides rides',
                          style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.segmentTrack,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${request.message}"',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isProcessing ? null : onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: isProcessing
                      ? const SkeletonBox(width: 50, height: 12, borderRadius: 6)
                      : const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isProcessing ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  child: isProcessing
                      ? const SkeletonBox(width: 50, height: 12, borderRadius: 6)
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
