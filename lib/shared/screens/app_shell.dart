import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';
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

    return Scaffold(
      body: Stack(
        children: [
          navigationShell,
          if (!isOnline)
            const Align(
              alignment: Alignment.topCenter,
              child: OfflineBanner(),
            ),
        ],
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: navigationShell.currentIndex,
        onTab: _onBranch,
      ),
    );
  }
}

// ── Bottom nav ─────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.currentIndex,
    required this.onTab,
  });

  /// 0 = Home  1 = Create  2 = Alerts  3 = Profile
  final int currentIndex;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(4, 8, 4, 8 + bottomInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NavItem(
              icon: Icons.explore_rounded,
              label: 'Home',
              selected: currentIndex == 0,
              onTap: () => onTab(0),
            ),
            _NavItem(
              icon: Icons.directions_bike_rounded,
              label: 'Create',
              selected: currentIndex == 1,
              onTap: () => onTab(1),
            ),
            _NavItem(
              icon: Icons.inbox_rounded,
              label: 'Alerts',
              selected: currentIndex == 2,
              onTap: () => onTab(2),
            ),
            _NavItem(
              icon: Icons.account_circle_rounded,
              label: 'Profile',
              selected: currentIndex == 3,
              onTap: () => onTab(3),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Regular nav item ───────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                icon,
                size: 23,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              style: TextStyle(
                fontSize: 11,
                height: 1,
                letterSpacing: 0.1,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

