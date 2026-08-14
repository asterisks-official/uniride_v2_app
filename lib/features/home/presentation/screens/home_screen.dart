import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../rides/presentation/providers/rides_feed_notifier.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/ride_card.dart';
import '../../../../shared/widgets/skeleton.dart';

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
    _scrollController.removeListener(_onScroll);
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
    final initial = current != null ? DateTime.parse(current) : DateTime.now();

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
    final notifier = ref.read(ridesFeedProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: notifier.refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Large title that collapses into a compact bar as you scroll.
            SliverAppBar.large(
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              title: const Text('Rides'),
              titleTextStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              flexibleSpace: const _LargeTitle(),
            ),

            _FilterHeader(
              dateFilter: feed.dateFilter,
              femaleOnly: feed.femaleOnly,
              onDateTap: () => _pickDate(context),
              onClearDate: () => notifier.setDateFilter(null),
              onFemaleOnlyToggle: notifier.setFemaleOnly,
            ),

            ..._buildBody(feed, notifier),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(RidesFeedState feed, RidesFeedNotifier notifier) {
    if (feed.status == RidesFeedStatus.loading && feed.rides.isEmpty) {
      return [
        SliverList.builder(
          itemCount: 4,
          itemBuilder: (_, _) => const RideCardSkeleton(),
        ),
      ];
    }

    if (feed.status == RidesFeedStatus.error && feed.rides.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorRetry(
            message: feed.errorMessage ?? 'Failed to load rides.',
            onRetry: notifier.refresh,
          ),
        ),
      ];
    }

    if (feed.status == RidesFeedStatus.success && feed.rides.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.directions_car_outlined,
            title: feed.dateFilter != null || feed.femaleOnly
                ? 'No rides match these filters'
                : 'No rides posted yet',
            subtitle: feed.dateFilter != null || feed.femaleOnly
                ? 'Clear a filter to see everything on offer.'
                : 'Pull down to refresh, or post a ride request so drivers can find you.',
          ),
        ),
      ];
    }

    return [
      SliverList.builder(
        itemCount: feed.rides.length + (feed.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= feed.rides.length) return const RideCardSkeleton();
          final ride = feed.rides[index];
          return _Enter(
            index: index,
            child: RideCard(
              ride: ride,
              onTap: () => context.push('/rides/${ride.id}'),
            ),
          );
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];
  }
}

// ── Large title ──────────────────────────────────────────────────────────────

class _LargeTitle extends StatelessWidget {
  const _LargeTitle();

  @override
  Widget build(BuildContext context) {
    return FlexibleSpaceBar(
      background: Container(color: AppColors.background),
      titlePadding: const EdgeInsets.only(left: 16, bottom: 14),
      title: const Text(
        'Rides',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.9,
          color: AppColors.textPrimary,
        ),
      ),
      expandedTitleScale: 1.0,
    );
  }
}

// ── Filters ──────────────────────────────────────────────────────────────────

/// Pinned so filters stay reachable in a long feed, with a hairline that only
/// appears once content has scrolled beneath it.
class _FilterHeader extends StatelessWidget {
  const _FilterHeader({
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
        ? DateFormat('EEE, MMM d').format(DateTime.parse(dateFilter!))
        : null;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _FilterDelegate(
        child: Row(
          children: [
            _Chip(
              icon: Icons.calendar_today_rounded,
              label: dateLabel ?? 'Any date',
              active: dateLabel != null,
              activeColor: AppColors.primary,
              onTap: onDateTap,
              onClear: dateLabel != null ? onClearDate : null,
            ),
            const SizedBox(width: 8),
            _Chip(
              icon: Icons.female_rounded,
              label: 'Female only',
              active: femaleOnly,
              activeColor: AppColors.genderFemale,
              onTap: () => onFemaleOnlyToggle(!femaleOnly),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDelegate extends SliverPersistentHeaderDelegate {
  _FilterDelegate({required this.child});

  final Widget child;
  static const _height = 56.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: _height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent ? AppColors.border : Colors.transparent,
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_FilterDelegate old) => old.child != child;
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final fg = active ? activeColor : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: active
              ? activeColor.withValues(alpha: 0.10)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: fg,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded, size: 15, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Entrance ─────────────────────────────────────────────────────────────────

/// A short fade-and-rise as cards first appear. Staggered by position and
/// capped, so a long list never delays its own tail.
class _Enter extends StatelessWidget {
  const _Enter({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (index.clamp(0, 6)) * 45;
    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
