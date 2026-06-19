import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/ride_card.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../rides/domain/models/ride.dart';
import '../../../rides/presentation/providers/my_rides_notifier.dart';
import '../../../rides/presentation/providers/rides_feed_notifier.dart';

// Charcoal (from theme's lightTextPrimary) — used for headings and the avatar.
const _charcoal = Color(0xFF111827);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(ridesFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(ridesFeedProvider);
    final auth = ref.watch(authNotifierProvider);
    final isRider = auth is Authenticated && auth.user.role == 'RIDER';

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: Column(
        children: [
          _HomeHeader(isRider: isRider),
          const _ActiveRideBanner(),
          _FeedSectionHeader(count: feed.rides.length, isRider: isRider),
          Expanded(
            child: _FeedBody(
              feed: feed,
              isRider: isRider,
              scrollController: _scrollController,
              onRefresh: () => ref.read(ridesFeedProvider.notifier).refresh(),
              onRetry: () => ref.read(ridesFeedProvider.notifier).refresh(),
              onRideTap: (id) => context.push('/rides/$id'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Charcoal header — greeting + avatar
// ---------------------------------------------------------------------------

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.isRider});
  final bool isRider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPad = MediaQuery.of(context).padding.top;
    final auth = ref.watch(authNotifierProvider);
    final firstName =
        auth is Authenticated ? auth.user.name.split(' ').first : 'there';
    final initials = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _charcoal,
                    letterSpacing: -0.6,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _charcoal,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
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

// ---------------------------------------------------------------------------
// Active ride banner
// ---------------------------------------------------------------------------

class _ActiveRideBanner extends ConsumerWidget {
  const _ActiveRideBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ride = ref.watch(activeRideProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        axisAlignment: -1,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: ride == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Padding(
              key: ValueKey(ride.id),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ActiveRideCard(
                ride: ride,
                onTap: () async {
                  await context.push('/rides/${ride.id}');
                  ref.invalidate(myRidesProvider);
                },
              ),
            ),
    );
  }
}

class _ActiveRideCard extends StatefulWidget {
  const _ActiveRideCard({required this.ride, required this.onTap});

  final Ride ride;
  final VoidCallback onTap;

  @override
  State<_ActiveRideCard> createState() => _ActiveRideCardState();
}

class _ActiveRideCardState extends State<_ActiveRideCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  ({String label, IconData icon, List<Color> gradient, bool searching})
      get _meta => switch (widget.ride.status) {
            'IN_PROGRESS' => (
                label: 'Ride in progress',
                icon: Icons.directions_bike_rounded,
                gradient: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                searching: false,
              ),
            'MATCHED' => (
                label: 'Matched — tap to view',
                icon: Icons.people_alt_rounded,
                gradient: const [AppColors.secondary, Color(0xFF16A34A)],
                searching: false,
              ),
            _ => (
                label: 'Finding your match',
                icon: Icons.radar_rounded,
                gradient: const [AppColors.primary, AppColors.primaryDark],
                searching: true,
              ),
          };

  @override
  Widget build(BuildContext context) {
    final m = _meta;
    final ride = widget.ride;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: m.gradient.last.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: m.gradient,
              ),
            ),
            child: Stack(
              children: [
                // Sweeping scan/shine across the card.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (_, _) {
                        final t = _anim.value;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(-1.4 + 2.8 * t, -0.4),
                              end: Alignment(-1.0 + 2.8 * t, 0.4),
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.16),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _AnimatedIconBadge(
                        icon: m.icon,
                        anim: _anim,
                        searching: m.searching,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const _LiveDot(),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    m.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${ride.originAddress} → ${ride.destAddress}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.85),
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 22),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Icon badge with an expanding pulse ring (radar feel while searching).
class _AnimatedIconBadge extends StatelessWidget {
  const _AnimatedIconBadge({
    required this.icon,
    required this.anim,
    required this.searching,
  });

  final IconData icon;
  final Animation<double> anim;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Expanding pulse rings.
          AnimatedBuilder(
            animation: anim,
            builder: (_, _) {
              return Stack(
                alignment: Alignment.center,
                children: List.generate(2, (i) {
                  final t = (anim.value + i / 2) % 1.0;
                  return Opacity(
                    opacity: (1.0 - t) * 0.45,
                    child: Container(
                      width: 30 + t * 26,
                      height: 30 + t * 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 1.4,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: searching
                ? AnimatedBuilder(
                    animation: anim,
                    builder: (_, child) => Transform.rotate(
                      angle: anim.value * 6.2831853,
                      child: child,
                    ),
                    child: Icon(icon, color: Colors.white, size: 21),
                  )
                : Icon(icon, color: Colors.white, size: 21),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
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
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feed section header
// ---------------------------------------------------------------------------

class _FeedSectionHeader extends StatelessWidget {
  const _FeedSectionHeader({required this.count, required this.isRider});
  final int count;
  final bool isRider;

  @override
  Widget build(BuildContext context) {
    final title = isRider ? 'Passengers to pick up' : 'Rides near you';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _charcoal,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _charcoal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feed body
// ---------------------------------------------------------------------------

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.feed,
    required this.isRider,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
    required this.onRideTap,
  });

  final RidesFeedState feed;
  final bool isRider;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final ValueChanged<String> onRideTap;

  @override
  Widget build(BuildContext context) {
    if (feed.status == RidesFeedStatus.loading && feed.rides.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
        itemCount: 5,
        itemBuilder: (_, _) => const RideCardSkeleton(),
      );
    }

    if (feed.status == RidesFeedStatus.error && feed.rides.isEmpty) {
      return ErrorRetry(
        message: feed.errorMessage ?? 'Failed to load rides.',
        onRetry: onRetry,
      );
    }

    if (feed.status == RidesFeedStatus.success && feed.rides.isEmpty) {
      return EmptyState(
        icon: isRider ? Icons.hail_rounded : Icons.directions_bike_outlined,
        title: isRider ? 'No ride requests yet' : 'No rides on offer yet',
        subtitle: isRider
            ? 'No passengers are looking for a ride right now. Check back soon.'
            : 'No riders are offering rides right now. Check back soon.',
        action: OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
          onPressed: () => onRefresh(),
        ),
      );
    }

    return RefreshIndicator(
      color: _charcoal,
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
        itemCount: feed.rides.length + (feed.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= feed.rides.length) {
            return const RideCardSkeleton();
          }
          final ride = feed.rides[index];
          return _AnimatedCard(
            key: ValueKey(ride.id),
            index: index,
            child: RideCard(
              ride: ride,
              onTap: () => onRideTap(ride.id),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Staggered entrance
// ---------------------------------------------------------------------------

class _AnimatedCard extends StatefulWidget {
  const _AnimatedCard({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.10),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: min(widget.index * 60, 300));
    if (delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
}
