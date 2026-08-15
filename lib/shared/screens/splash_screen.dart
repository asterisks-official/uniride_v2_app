import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/motion.dart';
import '../widgets/uni_loader.dart';

/// Shown while the session is restored and, for a rider signup, while the
/// application status is fetched.
///
/// It carries real waiting time, so it does more than sit there: the mark
/// breathes, the ring tracks around it, and the wordmark arrives a beat later.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _breathe,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_breathe.value);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // A halo that swells and fades, so the mark reads as lit
                    // from within rather than pasted on.
                    Container(
                      height: 118 + 16 * t,
                      width: 118 + 16 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(
                          alpha: 0.09 * (1 - t),
                        ),
                      ),
                    ),
                    UniLoader(
                      size: 108,
                      strokeWidth: 3.2,
                      glyph: Transform.scale(
                        scale: 0.98 + 0.04 * t,
                        child: child,
                      ),
                    ),
                  ],
                );
              },
              child: Container(
                height: 68,
                width: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.32),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car_filled,
                  color: Colors.white,
                  size: 33,
                ),
              ),
            ),
            const SizedBox(height: 34),
            const FadeSlideIn(
              delay: Duration(milliseconds: 140),
              child: Text(
                'UniRide',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const FadeSlideIn(
              delay: Duration(milliseconds: 280),
              child: Text(
                'Rides between students',
                style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
