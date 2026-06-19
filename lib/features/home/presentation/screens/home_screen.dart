import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/ride_card.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../rides/domain/models/ride.dart';
import '../../../rides/presentation/providers/my_rides_notifier.dart';
import '../../../rides/presentation/providers/rides_feed_notifier.dart';

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

  Future<void> _pickDate(BuildContext context) async {
    final notifier = ref.read(ridesFeedProvider.notifier);
    final current = ref.read(ridesFeedProvider).dateFilter;
    final initial =
        current != null ? DateTime.parse(current) : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (!context.mounted) return;
    if (picked != null) {
      notifier.setDateFilter(DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(ridesFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeHeader(),
            const _ActiveRideBanner(),
            _FilterBar(
              dateFilter: feed.dateFilter,
              femaleOnly: feed.femaleOnly,
              onDateTap: () => _pickDate(context),
              onClearDate: () =>
                  ref.read(ridesFeedProvider.notifier).setDateFilter(null),
              onFemaleOnlyToggle: (v) =>
                  ref.read(ridesFeedProvider.notifier).setFemaleOnly(v),
            ),
            Expanded(
              child: _FeedBody(
                feed: feed,
                scrollController: _scrollController,
                onRefresh: () =>
                    ref.read(ridesFeedProvider.notifier).refresh(),
                onRetry: () =>
                    ref.read(ridesFeedProvider.notifier).refresh(),
                onRideTap: (id) => context.push('/rides/$id'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _HomeHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final firstName =
        auth is Authenticated ? auth.user.name.split(' ').first : 'there';

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());
    final initials = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Container(
      color: AppColors.lightSurface,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.lightTextPrimary,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  today,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.lightMuted,
                  ),
                ),
              ],
            ),
          ),
          // Profile avatar
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: _InitialsAvatar(initials: initials),
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primary,
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Active ride banner — resumes an in-flight ride from anywhere
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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

class _ActiveRideCard extends StatelessWidget {
  const _ActiveRideCard({required this.ride, required this.onTap});

  final Ride ride;
  final VoidCallback onTap;

  ({String label, IconData icon, List<Color> gradient, bool live}) get _meta =>
      switch (ride.status) {
        'IN_PROGRESS' => (
            label: 'Ride in progress',
            icon: Icons.directions_bike_rounded,
            gradient: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
            live: true,
          ),
        'MATCHED' => (
            label: 'Matched — tap to view',
            icon: Icons.people_alt_rounded,
            gradient: const [AppColors.secondary, Color(0xFF16A34A)],
            live: true,
          ),
        _ => (
            label: 'Finding your match',
            icon: Icons.radar_rounded,
            gradient: const [AppColors.primary, AppColors.primaryDark],
            live: true,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final m = _meta;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: m.gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: m.gradient.last.withValues(alpha: 0.30),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(m.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (m.live) ...[
                        const _LiveDot(),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          m.label,
                          style: const TextStyle(
                            fontSize: 14.5,
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
                      fontSize: 12.5,
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
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }
}

// Pulsing white dot for the "live" indicator.
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
// Filter bar
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.dateFilter,
    required this.femaleOnly,
    required this.onDateTap,
    required this.onClearDate,
    required this.onFemaleOnlyToggle,
  });

  final String? dateFilter;
  final bool femaleOnly;
  final VoidCallback onDateTap;
  final VoidCallback onClearDate;
  final ValueChanged<bool> onFemaleOnlyToggle;

  @override
  Widget build(BuildContext context) {
    final dateLabel = dateFilter != null
        ? DateFormat('MMM d').format(DateTime.parse(dateFilter!))
        : null;

    return Container(
      color: AppColors.lightSurface,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          _FilterChip(
            icon: Icons.calendar_month_rounded,
            label: dateLabel ?? 'Any date',
            active: dateLabel != null,
            activeColor: AppColors.primary,
            onTap: onDateTap,
            trailing: dateLabel != null
                ? GestureDetector(
                    onTap: onClearDate,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            icon: Icons.female_rounded,
            label: 'Female only',
            active: femaleOnly,
            activeColor: const Color(0xFFDB2777),
            onTap: () => onFemaleOnlyToggle(!femaleOnly),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.10)
              : AppColors.lightBackground,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? activeColor : AppColors.lightBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? activeColor : AppColors.lightTextSecondary,
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? activeColor : AppColors.lightTextSecondary,
              ),
              child: Text(label),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
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
    required this.scrollController,
    required this.onRefresh,
    required this.onRetry,
    required this.onRideTap,
  });

  final RidesFeedState feed;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final ValueChanged<String> onRideTap;

  @override
  Widget build(BuildContext context) {
    if (feed.status == RidesFeedStatus.loading && feed.rides.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
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
        icon: Icons.directions_car_outlined,
        title: 'No rides available',
        subtitle: 'Try a different date or check back later.',
        action: OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
          onPressed: () => onRefresh(),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
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
