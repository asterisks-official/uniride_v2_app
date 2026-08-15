import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'uni_loader.dart';

/// How much visual weight a button carries.
enum AppButtonVariant {
  /// Solid brand fill. One per screen — the action you want pressed.
  filled,

  /// Brand wash fill. Secondary, but still a real action.
  tonal,

  /// Hairline outline on the surface. "Back", "Cancel", "Not now".
  outline,
}

/// The app's primary button.
///
/// Two things make it feel native rather than web-in-a-box: it shrinks under
/// the finger the moment it is touched (before any work starts, so the app
/// never feels unresponsive), and while it is busy it swaps its label for an
/// iOS-style activity indicator *at the same width*, so the layout does not
/// jump. Pair it with [AppLoadingController] when the work blocks the screen.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.variant = AppButtonVariant.filled,
    this.icon,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Replaces the label with a spinner and blocks presses.
  final bool loading;

  /// Shown beside the spinner while [loading]. Null keeps the button quiet —
  /// right when a full-screen HUD is already narrating the work.
  final String? loadingLabel;

  final AppButtonVariant variant;
  final IconData? icon;
  final double height;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.variant == AppButtonVariant.filled;
    final foreground = switch (widget.variant) {
      AppButtonVariant.filled => AppColors.onPrimary,
      AppButtonVariant.tonal => AppColors.primary,
      AppButtonVariant.outline => AppColors.textPrimary,
    };
    final background = switch (widget.variant) {
      AppButtonVariant.filled => AppColors.primary,
      AppButtonVariant.tonal => AppColors.primaryWash,
      AppButtonVariant.outline => AppColors.surface,
    };

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled
            ? (_) {
                _setPressed(true);
                HapticFeedback.lightImpact();
              }
            : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedOpacity(
          opacity: widget.onPressed == null && !widget.loading ? 0.45 : 1,
          duration: const Duration(milliseconds: 160),
          child: AnimatedScale(
            // Apple's press feedback is a small, fast shrink — big enough to
            // register, small enough that a mis-tap doesn't feel like a bounce.
            scale: _pressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              height: widget.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _pressed
                    ? Color.alphaBlend(
                        AppColors.dark.withValues(alpha: 0.12),
                        background,
                      )
                    : background,
                borderRadius: BorderRadius.circular(16),
                border: widget.variant == AppButtonVariant.outline
                    ? Border.all(color: AppColors.border)
                    : null,
                boxShadow: filled && !_pressed
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.24),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: widget.loading
                    ? _busyRow(foreground)
                    : _labelRow(foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _busyRow(Color foreground) {
    return Row(
      key: const ValueKey('busy'),
      mainAxisSize: MainAxisSize.min,
      children: [
        UniLoader(
          size: 22,
          color: foreground,
          trackColor: foreground.withValues(alpha: 0.25),
          strokeWidth: 2.4,
        ),
        if (widget.loadingLabel != null) ...[
          const SizedBox(width: 10),
          Text(
            widget.loadingLabel!,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.9),
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _labelRow(Color foreground) {
    return Row(
      key: ValueKey('label:${widget.label}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 19, color: foreground),
          const SizedBox(width: 9),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: foreground,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}
