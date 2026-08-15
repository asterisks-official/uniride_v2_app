import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/account_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../../shared/widgets/trust_score_ring.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../rides/presentation/providers/my_rides_notifier.dart';
import '../../../rides/presentation/providers/rides_feed_notifier.dart';
import '../../domain/models/user_profile.dart';
import '../providers/profile_notifier.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const _ProfileSkeleton(),
        error: (e, _) => ErrorRetry(
          message: e is AppException ? e.message : 'Could not load profile.',
          onRetry: () => ref.read(profileNotifierProvider.notifier).reload(),
        ),
        data: (profile) => _ProfileBody(profile: profile),
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const SkeletonBox(width: 88, height: 88, borderRadius: 44),
          const SizedBox(height: 16),
          const SkeletonBox(width: 160, height: 20),
          const SizedBox(height: 8),
          const SkeletonBox(width: 120, height: 14),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              SkeletonBox(width: 80, height: 60),
              SkeletonBox(width: 80, height: 60),
              SkeletonBox(width: 80, height: 60),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Loaded body ───────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = profile.stats;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            color: AppColors.surface,
            child: Column(
              children: [
                _Avatar(
                  name: profile.name,
                  url: profile.profilePictureUrl,
                  trustScore: stats?.trustScore ?? 50,
                ),
                const SizedBox(height: 16),
                Text(
                  profile.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (profile.university?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.university!,
                    style:
                        const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                if (profile.isRider) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified,
                            size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Verified Rider',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Stats row
          if (stats != null) ...[
            const SizedBox(height: 1),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  _StatCell(value: '${stats.ridesCompleted}', label: 'Rides'),
                  _VertDivider(),
                  _StatCell(
                    value: stats.averageRating > 0
                        ? stats.averageRating.toStringAsFixed(1)
                        : '—',
                    label: 'Rating',
                    prefix: stats.averageRating > 0
                        ? const Icon(Icons.star_rounded,
                            size: 14, color: AppColors.warning)
                        : null,
                  ),
                  _VertDivider(),
                  _StatCell(
                    value: '',
                    label: 'Trust',
                    customWidget:
                        TrustScoreRing(score: stats.trustScore, size: 32),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Rides & rider actions
          Container(
            color: AppColors.surface,
            child: Column(
              children: [
                if (profile.isRider)
                  _ModeSwitcher(
                    current: profile.activeMode,
                    onSwitch: (mode) => _switchMode(context, ref, mode),
                  ),
                if (profile.isRider) const Divider(height: 1, indent: 56),
                _MenuItem(
                  icon: Icons.directions_car_outlined,
                  label: 'My Rides',
                  onTap: () => context.push('/rides'),
                ),
                const Divider(height: 1, indent: 56),
                _MenuItem(
                  icon: profile.isRider
                      ? Icons.verified_outlined
                      : Icons.directions_car,
                  label: profile.isRider ? 'Rider status' : 'Become a Rider',
                  onTap: () => context.push('/verification'),
                ),
                const Divider(height: 1, indent: 56),
                _MenuItem(
                  icon: Icons.edit_outlined,
                  label: 'Edit profile',
                  onTap: () {}, // Phase 3
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Account actions
          Container(
            color: AppColors.surface,
            child: Column(
              children: [
                _MenuItem(
                  icon: Icons.logout,
                  label: 'Log out',
                  onTap: () =>
                      ref.read(authNotifierProvider.notifier).logout(),
                ),
                const Divider(height: 1, indent: 56),
                _MenuItem(
                  icon: Icons.delete_outline,
                  label: 'Delete account',
                  color: AppColors.error,
                  onTap: () => _confirmDelete(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Switch sides, then drop every cache that holds the old side's data.
  ///
  /// The switch returns new tokens, so anything already fetched belongs to the
  /// wrong audience: the feed shows the opposite market, and "my rides" is
  /// scoped to who you were. Clearing only the feed would leave a passenger
  /// looking at rider content and reads as a bug.
  Future<void> _switchMode(
    BuildContext context,
    WidgetRef ref,
    ActiveMode mode,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authNotifierProvider.notifier).switchMode(mode);

      ref.invalidate(ridesFeedProvider);
      ref.invalidate(myRidesProvider);
      ref.invalidate(profileNotifierProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            mode == ActiveMode.rider
                ? 'Switched to rider — showing ride requests'
                : 'Switched to passenger — showing ride offers',
          ),
        ),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Your data is permanently removed after 30 days. '
          'Active rides will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.url,
    required this.trustScore,
  });
  final String name;
  final String? url;
  final int trustScore;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: AppColors.segmentTrack,
          backgroundImage:
              url != null ? CachedNetworkImageProvider(url!) : null,
          child: url == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                )
              : null,
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: TrustScoreRing(score: trustScore, size: 36),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.prefix,
    this.customWidget,
  });
  final String value;
  final String label;
  final Widget? prefix;
  final Widget? customWidget;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          if (customWidget != null)
            customWidget!
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (prefix != null) ...[prefix!, const SizedBox(width: 2)],
                Text(
                  value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: AppColors.border);
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label, style: TextStyle(color: c)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: onTap,
    );
  }
}

/// Two-way switch between the passenger and rider views. Shown only to
/// approved riders — for everyone else the "Become a Rider" entry is the
/// relevant control.
class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.current, required this.onSwitch});

  final ActiveMode current;
  final ValueChanged<ActiveMode> onSwitch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz, size: 22, color: AppColors.textSecondary),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Browsing as',
                  style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.segmentTrack,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                for (final m in ActiveMode.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: current == m ? null : () => onSwitch(m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: current == m
                              ? AppColors.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: current == m
                              ? [
                                  BoxShadow(
                                    color: AppColors.textPrimary
                                        .withValues(alpha: 0.07),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          m.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: current == m
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: current == m
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            current == ActiveMode.rider
                ? 'Showing ride requests from passengers.'
                : 'Showing ride offers from drivers.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
