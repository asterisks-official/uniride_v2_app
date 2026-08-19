import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/account_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/motion.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../rides/presentation/providers/my_rides_notifier.dart';
import '../../../rides/presentation/providers/rides_feed_notifier.dart';
import '../../domain/models/user_profile.dart';
import '../providers/profile_notifier.dart';
import '../widgets/complete_profile_sheet.dart';

/// Horizontal gutter every card on this screen lines up to.
const _gutter = 16.0;

/// The account screen: who you are, how you are doing, and the handful of
/// switches that belong to the account rather than to a ride.
///
/// Built as one scroll of grouped cards on the app's own ground colour, which
/// is what the rest of the app looks like — the previous full-bleed white
/// slabs separated by 8px gaps were the only place in UniRide that read as
/// stock Material.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () => ref.read(profileNotifierProvider.notifier).reload(),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // Same collapsing large title as the feed, so moving between tabs
            // does not change the shape of the screen.
            SliverAppBar.large(
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              title: const Text('Profile'),
              titleTextStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(color: AppColors.background),
                titlePadding: const EdgeInsets.only(left: _gutter, bottom: 14),
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            ...profileAsync.when(
              loading: () => const [
                SliverToBoxAdapter(child: _ProfileSkeleton()),
              ],
              error: (e, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorRetry(
                    message: e is AppException
                        ? e.message
                        : 'Could not load profile.',
                    onRetry: () =>
                        ref.read(profileNotifierProvider.notifier).reload(),
                  ),
                ),
              ],
              data: (profile) => [
                SliverToBoxAdapter(child: _ProfileBody(profile: profile)),
              ],
            ),
            SliverToBoxAdapter(
              // The floating nav bar's footprint arrives on MediaQuery from the
              // shell, so the last card clears it without this screen having to
              // know the bar exists.
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loaded body ──────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        FadeSlideIn(child: _IdentityCard(profile: profile)),

        const SizedBox(height: 12),
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: _StatsRow(stats: profile.stats),
        ),

        if (profile.needsProfileCompletion) ...[
          const SizedBox(height: 12),
          FadeSlideIn(
            delay: const Duration(milliseconds: 90),
            child: _CompletionBanner(
              onTap: () => CompleteProfileSheet.show(context),
            ),
          ),
        ],

        const SizedBox(height: 12),
        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
          child: profile.isRider
              // An approved rider's live question is which side of the market
              // they are looking at today; an applicant's is how to become one.
              // Only ever one of the two is worth this much space.
              ? _ModeCard(
                  current: profile.activeMode,
                  onSwitch: (mode) => _switchMode(context, ref, mode),
                )
              : const _RiderCta(),
        ),

        const SizedBox(height: 22),
        FadeSlideIn(
          delay: const Duration(milliseconds: 160),
          child: _Section(
            title: 'Activity',
            rows: [
              _Row(
                icon: Icons.route_outlined,
                label: 'My rides',
                onTap: () => context.push('/rides'),
              ),
              if (profile.isRider)
                _Row(
                  icon: Icons.verified_outlined,
                  label: 'Rider status',
                  trailingText: 'Approved',
                  trailingColor: AppColors.success,
                  onTap: () => context.push('/verification'),
                ),
            ],
          ),
        ),

        const SizedBox(height: 22),
        FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          child: _Section(
            title: 'Details',
            rows: [
              _Row(
                icon: Icons.alternate_email_rounded,
                label: 'Email',
                trailingText: profile.email,
              ),
              if (profile.phone?.isNotEmpty == true)
                _Row(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  trailingText: profile.phone,
                ),
              if (profile.university?.isNotEmpty == true)
                _Row(
                  icon: Icons.school_outlined,
                  label: 'University',
                  trailingText: profile.university,
                ),
              if (profile.studentIdNumber?.isNotEmpty == true)
                _Row(
                  icon: Icons.badge_outlined,
                  label: 'Student ID',
                  trailingText: profile.studentIdNumber,
                ),
              if (profile.gender != null)
                _Row(
                  icon: Icons.person_outline_rounded,
                  label: 'Gender',
                  trailingText: profile.gender!.label,
                ),
              _Row(
                icon: Icons.edit_outlined,
                label: 'Edit profile',
                onTap: () => showAppSnack(
                  context,
                  'Editing your details is coming soon.',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),
        FadeSlideIn(
          delay: const Duration(milliseconds: 240),
          child: _Section(
            title: 'Account',
            rows: [
              _Row(
                icon: Icons.logout_rounded,
                label: 'Log out',
                onTap: () => ref.read(authNotifierProvider.notifier).logout(),
              ),
              _Row(
                icon: Icons.delete_outline_rounded,
                label: 'Delete account',
                danger: true,
                onTap: () => _confirmDelete(context, ref),
              ),
            ],
          ),
        ),
      ],
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
    try {
      await ref.read(authNotifierProvider.notifier).switchMode(mode);

      ref.invalidate(ridesFeedProvider);
      ref.invalidate(myRidesProvider);
      ref.invalidate(profileNotifierProvider);

      if (context.mounted) {
        showAppSnack(
          context,
          mode == ActiveMode.rider
              ? 'Switched to rider — showing ride requests'
              : 'Switched to passenger — showing ride offers',
        );
      }
    } on AppException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, isError: true);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
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

// ── Identity ─────────────────────────────────────────────────────────────────

/// Avatar, name and standing, on a tinted card.
///
/// Tinted rather than white because it is the one block on the screen that is
/// about *you* — everything below it is a list of controls, and a page of
/// identical white cards gives the eye nowhere to land first.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primaryWash, AppColors.surface],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(
                name: profile.name,
                url: profile.profilePictureUrl,
                verified: profile.isRider,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        height: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (profile.university?.isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(
                        profile.university!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _RolePill(profile: profile),
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Text(
              profile.bio!,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.url,
    required this.verified,
  });

  final String name;
  final String? url;
  final bool verified;

  static const _size = 74.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: _size,
            width: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.14),
              // A ring in the page's own surface colour, so the avatar reads as
              // sitting on the card rather than punched out of it.
              border: Border.all(color: AppColors.surface, width: 3),
              image: url != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(url!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: url == null
                ? Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          if (verified)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                height: 26,
                width: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.surface, width: 2.5),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Two letters where the name gives them: "Ayesha Rahman" is more
  /// recognisable as AR than as A.
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = profile.isRider
        ? (Icons.verified_rounded, AppColors.primary, 'Verified rider')
        : (Icons.person_rounded, AppColors.textSecondary, 'Passenger');

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats ────────────────────────────────────────────────────────────────────

/// Three tiles rather than one divided slab: each number gets its own accent,
/// and a tile that has nothing to say ("no ratings yet") can say so without
/// unbalancing the other two.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final UserStats? stats;

  @override
  Widget build(BuildContext context) {
    final rated = (stats?.totalRatings ?? 0) > 0;
    final trust = stats?.trustScore ?? 50;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.route_rounded,
              accent: AppColors.primary,
              value: '${stats?.ridesCompleted ?? 0}',
              label: 'Rides',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: Icons.star_rounded,
              accent: AppColors.warning,
              value: rated ? stats!.averageRating.toStringAsFixed(1) : '—',
              label: rated ? '${stats!.totalRatings} ratings' : 'No ratings',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: Icons.shield_rounded,
              accent: _trustColor(trust),
              value: '$trust',
              label: 'Trust score',
              meter: trust / 100,
            ),
          ),
        ],
      ),
    );
  }

  static Color _trustColor(int score) {
    if (score <= 40) return AppColors.error;
    if (score <= 70) return AppColors.warning;
    return AppColors.success;
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
    this.meter,
  });

  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  /// 0–1. Draws a bar under the value — only the trust score has a ceiling
  /// worth showing progress against.
  final double? meter;

  @override
  Widget build(BuildContext context) {
    return _Card(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: accent),
          const SizedBox(height: 9),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          if (meter != null) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: meter!.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.segmentTrack,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mode / rider CTA ─────────────────────────────────────────────────────────

/// Two-way switch between the passenger and rider views. Shown only to
/// approved riders — for everyone else [_RiderCta] is the relevant control.
class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.current, required this.onSwitch});

  final ActiveMode current;
  final ValueChanged<ActiveMode> onSwitch;

  @override
  Widget build(BuildContext context) {
    final rider = current == ActiveMode.rider;

    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                size: 19,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 9),
              const Text(
                'Browsing as',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // The consequence of the switch, kept next to the switch itself:
              // the feed changing under you is otherwise unexplained.
              SwapIn(
                value: rider,
                child: Text(
                  rider ? 'Ride requests' : 'Ride offers',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.segmentTrack,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                for (final m in ActiveMode.values)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: current == m ? null : () => onSwitch(m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: current == m
                              ? AppColors.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: current == m
                              ? [
                                  BoxShadow(
                                    color: AppColors.textPrimary.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 7,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              m == ActiveMode.rider
                                  ? Icons.two_wheeler_rounded
                                  : Icons.person_rounded,
                              size: 16,
                              color: current == m
                                  ? AppColors.primary
                                  : AppColors.muted,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              m.label,
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
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one thing a passenger can do here that changes what the app is for
/// them, so it gets a card instead of a row in a list.
class _RiderCta extends StatelessWidget {
  const _RiderCta();

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scale: 0.985,
      onTap: () => context.push('/verification'),
      child: _Card(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        shadowColor: AppColors.primary.withValues(alpha: 0.28),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                size: 23,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Become a rider',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Offer seats on trips you already make.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xCCFFFFFF),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xCCFFFFFF),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown to accounts made before gender and student ID were required. The
/// shell already prompts once per launch; this is the way back to that sheet
/// for anyone who dismissed it.
class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scale: 0.985,
      onTap: onTap,
      child: _Card(
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        color: AppColors.warning.withValues(alpha: 0.10),
        shadowColor: Colors.transparent,
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: AppColors.warning,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Finish your profile to book female-only rides.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grouped rows ─────────────────────────────────────────────────────────────

/// A titled group of rows in one card, iOS settings style.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_gutter + 6, 0, _gutter, 9),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppColors.muted,
            ),
          ),
        ),
        _Card(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                // Indented past the icon column, so the group reads as one
                // block rather than a stack of separate strips.
                if (i != rows.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 52),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailingText,
    this.trailingColor,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// A value, not an action. Rows carrying one and nothing else are read-only
  /// and deliberately show no chevron.
  final String? trailingText;

  final Color? trailingColor;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? AppColors.error : AppColors.textPrimary;

    return PressableScale(
      scale: 0.99,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: danger ? AppColors.error : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: tint,
              ),
            ),
            const Spacer(),
            if (trailingText != null)
              Flexible(
                child: Text(
                  trailingText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: trailingColor != null
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: trailingColor ?? AppColors.textSecondary,
                  ),
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: danger ? AppColors.error : AppColors.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Card shell ───────────────────────────────────────────────────────────────

/// The one card decoration this screen uses, matching [RideCard]'s: a soft
/// two-stop shadow rather than a hairline border, which is what keeps a column
/// of these from reading as a stack of boxes.
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: _gutter),
    this.color,
    this.gradient,
    this.shadowColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  final Gradient? gradient;
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final shadow = shadowColor ?? AppColors.textPrimary.withValues(alpha: 0.05);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: shadow.a == 0
            ? null
            : [
                BoxShadow(
                  color: shadow,
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.03),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: child,
    );
  }
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: _gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: double.infinity, height: 128, borderRadius: 20),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 96,
                  borderRadius: 20,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 96,
                  borderRadius: 20,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 96,
                  borderRadius: 20,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(width: double.infinity, height: 96, borderRadius: 20),
          SizedBox(height: 22),
          SkeletonBox(width: 90, height: 12, borderRadius: 6),
          SizedBox(height: 9),
          SkeletonBox(width: double.infinity, height: 106, borderRadius: 20),
        ],
      ),
    );
  }
}
