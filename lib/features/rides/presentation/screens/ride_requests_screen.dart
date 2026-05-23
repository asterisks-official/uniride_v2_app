import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Set<String> _processing = {};
  String? _error;

  Future<bool> _respond(String requestId, String action) async {
    if (_processing.contains(requestId)) return false;
    setState(() {
      _processing.add(requestId);
      _error = null;
    });

    try {
      await ref
          .read(ridesRepositoryProvider)
          .respondToRequest(widget.rideId, requestId, action);

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'ACCEPT'
                  ? 'Request accepted — ride is now matched!'
                  : 'Request declined.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor:
                action == 'ACCEPT' ? AppColors.secondary : null,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _processing.remove(requestId);
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
      return false;
    }
  }

  void _refresh() => ref.invalidate(rideRequestsProvider(widget.rideId));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(rideRequestsProvider(widget.rideId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: async.when(
          data: (reqs) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Join Requests'),
              if (reqs.isNotEmpty)
                Text(
                  '${reqs.length} pending',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
          loading: () => const Text('Join Requests'),
          error: (_, _) => const Text('Join Requests'),
        ),
      ),
      body: Column(
        children: [
          if (_error != null) _ErrorBanner(message: _error!),
          Expanded(
            child: async.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: 4,
                itemBuilder: (_, _) => const RequestCardSkeleton(),
              ),
              error: (e, _) => ErrorRetry(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: _refresh,
              ),
              data: (requests) => requests.isEmpty
                  ? const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'No pending requests',
                      subtitle: 'New requests will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: requests.length,
                        itemBuilder: (context, i) => _AnimatedRequestCard(
                          request: requests[i],
                          index: i,
                          isProcessing:
                              _processing.contains(requests[i].id),
                          onAccept: () => _respond(requests[i].id, 'ACCEPT'),
                          onDecline: () =>
                              _respond(requests[i].id, 'DECLINE'),
                          onDismissed: _refresh,
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

// ── Animated card wrapper ─────────────────────────────────────────────────────

class _AnimatedRequestCard extends StatefulWidget {
  const _AnimatedRequestCard({
    required this.request,
    required this.index,
    required this.isProcessing,
    required this.onAccept,
    required this.onDecline,
    required this.onDismissed,
  });

  final RideRequest request;
  final int index;
  final bool isProcessing;
  final Future<bool> Function() onAccept;
  final Future<bool> Function() onDecline;
  final VoidCallback onDismissed;

  @override
  State<_AnimatedRequestCard> createState() => _AnimatedRequestCardState();
}

class _AnimatedRequestCardState extends State<_AnimatedRequestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);

    Future.delayed(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) _entryCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Dismissible(
          key: Key(widget.request.id),
          direction: widget.isProcessing
              ? DismissDirection.none
              : DismissDirection.horizontal,
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.35,
            DismissDirection.endToStart: 0.35,
          },
          movementDuration: const Duration(milliseconds: 200),
          resizeDuration: const Duration(milliseconds: 180),
          confirmDismiss: (dir) async {
            HapticFeedback.lightImpact();
            final result = dir == DismissDirection.startToEnd
                ? await widget.onAccept()
                : await widget.onDecline();
            if (result) {
              Future.delayed(
                const Duration(milliseconds: 320),
                widget.onDismissed,
              );
            }
            return result;
          },
          background: _SwipeHint(accept: true),
          secondaryBackground: _SwipeHint(accept: false),
          child: _RequestCardContent(
            request: widget.request,
            isProcessing: widget.isProcessing,
            onAccept: widget.onAccept,
            onDecline: widget.onDecline,
            onDismissed: widget.onDismissed,
          ),
        ),
      ),
    );
  }
}

// ── Swipe hint background ─────────────────────────────────────────────────────

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.accept});

  final bool accept;

  @override
  Widget build(BuildContext context) {
    final color = accept ? AppColors.secondary : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment:
            accept ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!accept) ...[
            Text(
              'Decline',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            accept ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 30,
          ),
          if (accept) ...[
            const SizedBox(width: 8),
            Text(
              'Accept',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Card content ──────────────────────────────────────────────────────────────

class _RequestCardContent extends StatelessWidget {
  const _RequestCardContent({
    required this.request,
    required this.isProcessing,
    required this.onAccept,
    required this.onDecline,
    required this.onDismissed,
  });

  final RideRequest request;
  final bool isProcessing;
  final Future<bool> Function() onAccept;
  final Future<bool> Function() onDecline;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final passenger = request.passenger;
    final name = passenger?.name ?? 'Passenger';
    final avatar = passenger?.profilePictureUrl;
    final rating = passenger?.averageRating ?? 0.0;
    final rides = passenger?.ridesCompleted ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Passenger info row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _PassengerAvatar(name: name, url: avatar, radius: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating > 0
                                      ? rating.toStringAsFixed(1)
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _Dot(),
                                const SizedBox(width: 8),
                                Text(
                                  '$rides rides',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Message
                  if (request.message != null &&
                      request.message!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.format_quote_rounded,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              request.message!,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Swipe hint label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.chevron_left,
                          size: 13, color: AppColors.muted),
                      SizedBox(width: 3),
                      Text(
                        'Swipe or tap to decide',
                        style:
                            TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.chevron_right,
                          size: 13, color: AppColors.muted),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Decline',
                          icon: Icons.close_rounded,
                          color: AppColors.error,
                          filled: false,
                          disabled: isProcessing,
                          onTap: () async {
                            final ok = await onDecline();
                            if (ok) onDismissed();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          label: 'Accept',
                          icon: Icons.check_rounded,
                          color: AppColors.secondary,
                          filled: true,
                          disabled: isProcessing,
                          onTap: () async {
                            final ok = await onAccept();
                            if (ok) onDismissed();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Processing overlay
            if (isProcessing)
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: isProcessing ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    if (filled) {
      return ElevatedButton.icon(
        onPressed: disabled ? null : onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: shape,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: disabled ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: disabled ? color.withValues(alpha: 0.4) : color),
        minimumSize: const Size(0, 48),
        shape: shape,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Passenger avatar ──────────────────────────────────────────────────────────

class _PassengerAvatar extends StatelessWidget {
  const _PassengerAvatar({
    required this.name,
    required this.url,
    required this.radius,
  });

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.segmentTrack,
        backgroundImage:
            url != null ? CachedNetworkImageProvider(url!) : null,
        child: url == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: radius * 0.65,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              )
            : null,
      ),
    );
  }
}

// ── Tiny helpers ──────────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 3,
        height: 3,
        decoration: const BoxDecoration(
          color: AppColors.muted,
          shape: BoxShape.circle,
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AppColors.error, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                    color: AppColors.error, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
