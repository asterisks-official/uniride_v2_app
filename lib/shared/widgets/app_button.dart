import 'package:flutter/material.dart';

import 'skeleton.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SkeletonBox(width: 80, height: 16, borderRadius: 8)
          : Text(label),
    );
  }
}
