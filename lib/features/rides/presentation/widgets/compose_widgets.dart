import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/motion.dart';

/// The card decoration the compose screen uses throughout — the same soft
/// two-stop shadow as [RideCard], so a posted ride and the form that made it
/// look like the same app.
class ComposeCard extends StatelessWidget {
  const ComposeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: gradient == null ? (color ?? AppColors.surface) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.05),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.textPrimary.withValues(alpha: 0.03),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: child,
  );
}

class ComposeLabel extends StatelessWidget {
  const ComposeLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 9),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
        color: AppColors.muted,
      ),
    ),
  );
}

/// Two-option segmented control. Used for direction and for who can join.
class ComposeSegmented<T> extends StatelessWidget {
  const ComposeSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.accent = AppColors.primary,
  });

  final List<(T value, String label, IconData? icon)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.segmentTrack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (v, label, icon) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: v == value ? null : () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: v == value ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: v == value
                        ? [
                            BoxShadow(
                              color: AppColors.textPrimary.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 7,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 16,
                          color: v == value ? accent : AppColors.muted,
                        ),
                        const SizedBox(width: 7),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: v == value
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: v == value
                                ? accent
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A tappable row that shows what is currently chosen — place, campus, time.
class ComposeChoiceRow extends StatelessWidget {
  const ComposeChoiceRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.placeholder = false,
    this.accent = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  /// Nothing chosen yet — the title reads as a prompt, not a value.
  final bool placeholder;

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scale: 0.985,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Icon(icon, size: 21, color: placeholder ? AppColors.muted : accent),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: placeholder
                          ? FontWeight.w500
                          : FontWeight.w600,
                      color: placeholder
                          ? AppColors.muted
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// A time shortcut. The whole point of the compose screen's three-tap target
/// is that one of these is usually right.
class ComposeChip extends StatelessWidget {
  const ComposeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = AppColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
