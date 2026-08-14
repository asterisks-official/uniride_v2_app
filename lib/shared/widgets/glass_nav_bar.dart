import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Vertical space a [GlassNavBar] occupies above the safe area. Screens under
/// the shell get this added to their bottom padding so content can scroll
/// *behind* the glass without ending up trapped underneath it.
const double kGlassNavHeight = 64.0;
const double kGlassNavMargin = 14.0;
const double kGlassNavReservedSpace = kGlassNavHeight + kGlassNavMargin * 2;

/// A floating, translucent tab bar in the current iOS idiom: a blurred capsule
/// that hovers over the content with a sliding selection pill, paired with a
/// detached circular action button.
///
/// Deliberately not a [BottomNavigationBar] — the host [Scaffold] must set
/// `extendBody: true` and render this in a stack so there is live content
/// behind it. Blur over an opaque background reads as flat grey.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
    this.action,
  });

  final int currentIndex;
  final List<GlassNavItem> items;
  final ValueChanged<int> onTap;

  /// Optional trailing button, detached from the capsule.
  final GlassNavAction? action;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: kGlassNavMargin + bottomInset,
      ),
      child: Row(
        children: [
          Expanded(
            child: _GlassCapsule(
              currentIndex: currentIndex,
              items: items,
              onTap: onTap,
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 10),
            _ActionButton(action: action!),
          ],
        ],
      ),
    );
  }
}

class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class GlassNavAction {
  const GlassNavAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

// ── Capsule ──────────────────────────────────────────────────────────────────

class _GlassCapsule extends StatelessWidget {
  const _GlassCapsule({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<GlassNavItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(kGlassNavHeight / 2));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          // Broad ambient shadow — sells the "floating above content" read.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: kGlassNavHeight,
            decoration: BoxDecoration(
              borderRadius: radius,
              // Translucent so the blurred content tints the material.
              color: Colors.white.withValues(alpha: 0.72),
              // Specular rim: brighter at the top edge, like glass catching light.
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.65),
                width: 0.8,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / items.length;
                return Stack(
                  children: [
                    // Sliding selection pill.
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 340),
                      curve: Curves.easeOutCubic,
                      left: itemWidth * currentIndex,
                      top: 0,
                      bottom: 0,
                      width: itemWidth,
                      child: Center(
                        child: Container(
                          height: kGlassNavHeight - 14,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              (kGlassNavHeight - 14) / 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavItem(
                              item: items[i],
                              selected: i == currentIndex,
                              onTap: () {
                                if (i != currentIndex) {
                                  HapticFeedback.selectionClick();
                                }
                                onTap(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryDark : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Subtle lift on selection, the way SF Symbols animate on switch.
              AnimatedScale(
                scale: selected ? 1.0 : 0.92,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.1,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detached action button ───────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.action});

  final GlassNavAction action;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    lowerBound: 0.90,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.action.label,
      child: GestureDetector(
        onTapDown: (_) => _press.reverse(),
        onTapUp: (_) {
          _press.forward();
          HapticFeedback.lightImpact();
          widget.action.onTap();
        },
        onTapCancel: () => _press.forward(),
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _press, curve: Curves.easeOut),
          child: Container(
            width: kGlassNavHeight,
            height: kGlassNavHeight,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.40),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.30),
                width: 0.8,
              ),
            ),
            child: Icon(widget.action.icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}
