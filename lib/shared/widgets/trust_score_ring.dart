import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Circular progress ring displaying a trust score (0–100).
/// Color: red ≤40, amber 41–70, green ≥71.
class TrustScoreRing extends StatelessWidget {
  const TrustScoreRing({super.key, required this.score, this.size = 36});

  final int score;
  final double size;

  Color get _color {
    if (score <= 40) return AppColors.error;
    if (score <= 70) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(_color),
            strokeWidth: 3,
          ),
          Text(
            '$score',
            style: TextStyle(
              fontSize: size * 0.28,
              fontWeight: FontWeight.w700,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
