import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

class RideTypeScreen extends StatefulWidget {
  const RideTypeScreen({super.key});

  @override
  State<RideTypeScreen> createState() => _RideTypeScreenState();
}

class _RideTypeScreenState extends State<RideTypeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<T> _anim<T>(Tween<T> t, double from, double to) => t.animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(from, to, curve: Curves.easeOutCubic),
        ),
      );

  void _pick(String type) {
    HapticFeedback.selectionClick();
    context.push('/ride-create', extra: {'type': type});
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    final headerFade = _anim(Tween(begin: 0.0, end: 1.0), 0.0, 0.55);
    final headerSlide = _anim(
        Tween(begin: const Offset(0, 0.08), end: Offset.zero), 0.0, 0.55);

    final card1Fade = _anim(Tween(begin: 0.0, end: 1.0), 0.18, 0.72);
    final card1Slide = _anim(
        Tween(begin: const Offset(0, 0.10), end: Offset.zero), 0.18, 0.72);

    final card2Fade = _anim(Tween(begin: 0.0, end: 1.0), 0.32, 0.86);
    final card2Slide = _anim(
        Tween(begin: const Offset(0, 0.10), end: Offset.zero), 0.32, 0.86);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 32, 20, bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeTransition(
                  opacity: headerFade,
                  child: SlideTransition(
                    position: headerSlide,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'How are you\ntravelling today?',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.lightTextPrimary,
                            letterSpacing: -0.8,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pick your role for this trip',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.lightTextSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                FadeTransition(
                  opacity: card1Fade,
                  child: SlideTransition(
                    position: card1Slide,
                    child: _RoleCard(
                      title: "I'm Offering a Ride",
                      subtitle: 'Share your bike and earn on your commute',
                      icon: Icons.directions_bike_rounded,
                      accentColor: AppColors.primary,
                      onTap: () => _pick('OFFER'),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                FadeTransition(
                  opacity: card2Fade,
                  child: SlideTransition(
                    position: card2Slide,
                    child: _RoleCard(
                      title: 'I Need a Ride',
                      subtitle: 'Find a biker heading your way',
                      icon: Icons.hail_rounded,
                      accentColor: const Color(0xFF60A5FA),
                      onTap: () => _pick('REQUEST'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    reverseDuration: const Duration(milliseconds: 200),
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 1.0, end: 0.972).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeIn),
    );

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) => Transform.scale(scale: scale.value, child: child),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.lightBorder.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.accentColor.withValues(alpha: 0.12),
                      widget.accentColor.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: widget.accentColor.withValues(alpha: 0.85),
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.lightTextPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.lightTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.lightMuted,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
