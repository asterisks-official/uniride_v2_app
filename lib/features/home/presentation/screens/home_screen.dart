import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
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
    final auth = ref.watch(authNotifierProvider);
    final isRider = auth is Authenticated && auth.user.role == 'RIDER';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rides'),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/rides/create'),
        icon: const Icon(Icons.add),
        label: Text(isRider ? 'Offer Ride' : 'Request Ride'),
      ),
      body: Column(
        children: [
          // ── Filter chips ─────────────────────────────────────────────────────
          _FilterBar(
            dateFilter: feed.dateFilter,
            femaleOnly: feed.femaleOnly,
            onDateTap: () => _pickDate(context),
            onClearDate: () =>
                ref.read(ridesFeedProvider.notifier).setDateFilter(null),
            onFemaleOnlyToggle: (v) =>
                ref.read(ridesFeedProvider.notifier).setFemaleOnly(v),
          ),

          // ── Feed body ────────────────────────────────────────────────────────
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
    );
  }
}

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Date chip
          GestureDetector(
            onTap: onDateTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: dateLabel != null
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.segmentTrack,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: dateLabel != null
                      ? AppColors.primary
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: dateLabel != null
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateLabel ?? 'Any date',
                    style: TextStyle(
                      fontSize: 13,
                      color: dateLabel != null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: dateLabel != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  if (dateLabel != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onClearDate,
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Female Only chip
          GestureDetector(
            onTap: () => onFemaleOnlyToggle(!femaleOnly),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: femaleOnly
                    ? const Color(0xFFDB2777).withValues(alpha: 0.1)
                    : AppColors.segmentTrack,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: femaleOnly
                      ? const Color(0xFFDB2777)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.female,
                    size: 14,
                    color: femaleOnly
                        ? const Color(0xFFDB2777)
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Female only',
                    style: TextStyle(
                      fontSize: 13,
                      color: femaleOnly
                          ? const Color(0xFFDB2777)
                          : AppColors.textSecondary,
                      fontWeight: femaleOnly
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    // Initial skeleton
    if (feed.status == RidesFeedStatus.loading && feed.rides.isEmpty) {
      return ListView.builder(
        itemCount: 5,
        itemBuilder: (_, _) => const RideCardSkeleton(),
      );
    }

    // Full-page error (no existing data)
    if (feed.status == RidesFeedStatus.error && feed.rides.isEmpty) {
      return ErrorRetry(
        message: feed.errorMessage ?? 'Failed to load rides.',
        onRetry: onRetry,
      );
    }

    // Empty state
    if (feed.status == RidesFeedStatus.success && feed.rides.isEmpty) {
      return EmptyState(
        icon: Icons.directions_car_outlined,
        title: 'No rides available',
        subtitle: 'Try a different date or check back later.',
        action: OutlinedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          onPressed: () => onRefresh(),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: feed.rides.length + (feed.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= feed.rides.length) {
            return const RideCardSkeleton();
          }
          final ride = feed.rides[index];
          return RideCard(
            ride: ride,
            onTap: () => onRideTap(ride.id),
          );
        },
      ),
    );
  }
}
