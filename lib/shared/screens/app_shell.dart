import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/connectivity_service.dart';
import '../../features/profile/presentation/providers/profile_notifier.dart';
import '../../features/profile/presentation/widgets/complete_profile_sheet.dart';
import '../widgets/glass_nav_bar.dart';
import '../widgets/offline_banner.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Guards against re-opening the sheet on every rebuild while it is already
  /// on screen, or after the user has just completed it.
  bool _promptShown = false;

  void _onBranch(int index) => widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );

  /// Accounts created before gender and student ID were required get one
  /// blocking prompt. Deferred to after the frame because showing a modal
  /// during build throws.
  void _maybePromptCompletion() {
    if (_promptShown) return;
    final profile = ref.read(profileNotifierProvider).asData?.value;
    if (profile == null || !profile.needsProfileCompletion) return;

    _promptShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) CompleteProfileSheet.show(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;

    final isOnline = ref.watch(isOnlineProvider).maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );

    ref.watch(profileNotifierProvider);
    _maybePromptCompletion();

    final mq = MediaQuery.of(context);

    return Scaffold(
      // The nav floats over the content, so the body must extend beneath it —
      // otherwise the backdrop blur has nothing but the scaffold colour to
      // sample and the glass reads as flat grey.
      extendBody: true,
      body: Stack(
        children: [
          // Hand the branch an inset equal to the bar's footprint so lists and
          // SafeArea-aware screens can scroll clear of it without each screen
          // needing to know the nav exists.
          MediaQuery(
            data: mq.copyWith(
              padding: mq.padding.copyWith(
                bottom: mq.padding.bottom + kGlassNavReservedSpace,
              ),
            ),
            child: navigationShell,
          ),
          if (!isOnline)
            const Align(
              alignment: Alignment.topCenter,
              child: OfflineBanner(),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassNavBar(
              currentIndex: navigationShell.currentIndex,
              onTap: _onBranch,
              items: const [
                GlassNavItem(
                  icon: CupertinoIcons.house,
                  selectedIcon: CupertinoIcons.house_fill,
                  label: 'Home',
                ),
                GlassNavItem(
                  icon: CupertinoIcons.bell,
                  selectedIcon: CupertinoIcons.bell_fill,
                  label: 'Alerts',
                ),
                GlassNavItem(
                  icon: CupertinoIcons.person,
                  selectedIcon: CupertinoIcons.person_fill,
                  label: 'Profile',
                ),
              ],
              action: GlassNavAction(
                icon: CupertinoIcons.plus,
                label: 'Offer a ride',
                onTap: () => context.push('/rides/create'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
