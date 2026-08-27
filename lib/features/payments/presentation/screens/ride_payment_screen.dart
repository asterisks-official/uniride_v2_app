import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../rides/presentation/screens/ride_detail_screen.dart'
    show rideDetailProvider;

/// What changes hands at the end of the trip.
///
/// Cash, because that is what this service actually runs on — the completion
/// job writes the payment row with `gatewayProvider` null and a comment saying
/// so. There is nothing here to authorise and no gateway to wait for; the two
/// of them settle it on the pavement and this makes sure they agree on the
/// number before they do.
///
/// Which is the whole job. The fare was fixed when the ride was posted and
/// neither side has seen it since the feed — a screen that says it plainly, to
/// both people at once, is what stops the argument.
class RidePaymentScreen extends ConsumerWidget {
  const RidePaymentScreen({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rideDetailProvider(rideId));
    final auth = ref.watch(authNotifierProvider);
    final me = auth is Authenticated ? auth.user.id : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment'),
        automaticallyImplyLeading: false,
      ),
      body: async.when(
        loading: () => const Center(child: SkeletonBox(width: 200, height: 20)),
        error: (e, _) => ErrorRetry(
          message: e.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(rideDetailProvider(rideId)),
        ),
        data: (ride) {
          // The passenger hands the money over; the rider takes it. Showing
          // both people "pay ৳240" would have one of them paying twice.
          final iPay = me != null && ride.passenger?.id == me;
          final other = iPay ? ride.poster.name : (ride.passenger?.name ?? 'your passenger');

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Icon(
                    iPay ? Icons.payments_outlined : Icons.savings_outlined,
                    size: 44,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    iPay ? 'Pay in cash' : 'Collect in cash',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '৳${ride.fare.toStringAsFixed(0)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 44,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    iPay ? 'to $other' : 'from $other',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.segmentTrack,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            // Said plainly rather than implied. UniRide takes
                            // no card and holds no money, and a screen that
                            // looked like a checkout would suggest otherwise.
                            'UniRide does not handle the money. This is the '
                            'fare agreed when the ride was posted — settle it '
                            'directly.',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AppButton(
                    label: iPay ? 'Paid — continue' : 'Received — continue',
                    onPressed: () =>
                        context.pushReplacement('/rides/$rideId/rate'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
