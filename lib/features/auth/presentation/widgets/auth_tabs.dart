import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class AuthTabs extends StatelessWidget {
  const AuthTabs({super.key, required this.index, required this.onChanged});

  /// 0 = Login, 1 = Register.
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.segmentTrack,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _segment('Login', 0),
          _segment('Register', 1),
        ],
      ),
    );
  }

  Widget _segment(String label, int i) {
    final active = index == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(i),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.textPrimary : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
