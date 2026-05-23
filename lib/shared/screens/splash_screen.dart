import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/skeleton.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.directions_car, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'UniRide',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 160,
              child: SkeletonBox(width: 160, height: 4, borderRadius: 2),
            ),
          ],
        ),
      ),
    );
  }
}
