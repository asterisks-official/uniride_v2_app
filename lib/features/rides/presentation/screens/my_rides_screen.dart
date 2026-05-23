import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/auth/presentation/providers/auth_notifier.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/ride_card.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../domain/models/ride.dart';
import '../providers/my_rides_notifier.dart';

const _activeStatuses = {'SEARCHING', 'MATCHED', 'IN_PROGRESS'};

class MyRidesScreen extends ConsumerWidget {
  const MyRidesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final isRider = auth is Authenticated && auth.user.role == 'RIDER';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Rides'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: isRider ? 'Offer Ride' : 'Request Ride',
              onPressed: () => context.push('/rides/create'),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: ref.watch(myRidesProvider).when(
              loading: () => ListView.builder(
                itemCount: 5,
                itemBuilder: (_, _) => const RideCardSkeleton(),
              ),
              error: (e, _) => ErrorRetry(
                message: e.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.read(myRidesProvider.notifier).reload(),
              ),
              data: (rides) => TabBarView(
                children: [
                  _RidesList(
                    rides: rides
                        .where((r) => _activeStatuses.contains(r.status))
                        .toList(),
                    emptyTitle: 'No active rides',
                    emptySubtitle: 'Join a ride from the home tab.',
                    onRefresh: () => ref.read(myRidesProvider.notifier).reload(),
                    onRideTap: (id) => context.push('/rides/$id'),
                  ),
                  _RidesList(
                    rides: rides
                        .where((r) => !_activeStatuses.contains(r.status))
                        .toList(),
                    emptyTitle: 'No past rides',
                    emptySubtitle:
                        'Your completed or cancelled rides appear here.',
                    onRefresh: () => ref.read(myRidesProvider.notifier).reload(),
                    onRideTap: (id) => context.push('/rides/$id'),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class _RidesList extends StatelessWidget {
  const _RidesList({
    required this.rides,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
    required this.onRideTap,
  });

  final List<Ride> rides;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onRideTap;

  @override
  Widget build(BuildContext context) {
    if (rides.isEmpty) {
      return EmptyState(
        icon: Icons.directions_car_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rides.length,
        itemBuilder: (context, index) {
          final ride = rides[index];
          return RideCard(
            ride: ride,
            onTap: () => onRideTap(ride.id),
          );
        },
      ),
    );
  }
}
