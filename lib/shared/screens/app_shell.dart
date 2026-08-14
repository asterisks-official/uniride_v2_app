import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/connectivity_service.dart';
import '../widgets/glass_nav_bar.dart';
import '../widgets/offline_banner.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onBranch(int index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );

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
