import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Social sign-in buttons. The backend has no OAuth endpoints yet, so these
/// surface a "coming soon" message rather than performing a sign-in.
class SocialLoginRow extends StatelessWidget {
  const SocialLoginRow({super.key});

  void _comingSoon(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-in is coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _comingSoon(context, 'Google'),
            icon: const Icon(
              Icons.g_mobiledata,
              size: 30,
              color: Color(0xFFEA4335),
            ),
            label: const Text('Google'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _comingSoon(context, 'Facebook'),
            icon: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
            label: const Text('Facebook'),
          ),
        ),
      ],
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'Or login with'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
