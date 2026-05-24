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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeHeader(),
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
                onRefresh: () => ref.read(ridesFeedProvider.notifier).refresh(),
                onRetry: () => ref.read(ridesFeedProvider.notifier).refresh(),
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
    final firstName = auth is Authenticated
        ? auth.user.name.split(' ').first
        : 'there';

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final emoji = hour < 12 ? '☀️' : hour < 17 ? '🌤️' : '🌆';
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    final initials = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting $emoji',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  today,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
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
          ),
        ],
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
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
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
              : AppColors.background,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? activeColor : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? activeColor : AppColors.textSecondary,
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
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
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
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
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
// Staggered entrance wrapper
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
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final delay = Duration(milliseconds: min(widget.index * 65, 320));
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
