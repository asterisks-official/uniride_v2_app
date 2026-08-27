import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// A button you drag rather than tap.
///
/// For the one action on a screen that should never happen by accident.
/// Requesting a ride puts your name in front of a stranger and commits you to
/// turning up, and it sits at the bottom of a scrolling page — exactly where a
/// thumb lands when it means to scroll.
///
/// Sized and shaped like [AppButton] on purpose. It is the same slot in the
/// same layout; only the gesture is deliberately harder.
class SlideAction extends StatefulWidget {
  const SlideAction({
    super.key,
    required this.label,
    required this.onConfirm,
    this.busyLabel,
    this.busy = false,
    this.enabled = true,
    this.height = 56,
    this.icon = Icons.arrow_forward_rounded,
    this.color,
  });

  final String label;

  /// Fired once, when the thumb is released past the threshold.
  final VoidCallback onConfirm;

  /// Shown in place of [label] while [busy]. Defaults to [label].
  final String? busyLabel;

  /// Locks the thumb at the far end and shows a spinner — the request is in
  /// flight. Sliding again while it lands would send a second one.
  final bool busy;

  final bool enabled;
  final double height;
  final IconData icon;

  /// Track colour. Defaults to the app's primary.
  ///
  /// Worth setting when two slides live on the same screen at different points
  /// in a flow — colour is what stops the second one being read as a repeat of
  /// the first. The thumb stays white and takes its icon from this, so any
  /// colour dark enough for white text works.
  final Color? color;

  @override
  State<SlideAction> createState() => _SlideActionState();
}

class _SlideActionState extends State<SlideAction>
    with SingleTickerProviderStateMixin {
  /// Far enough that a stray sideways scroll cannot reach it, short enough
  /// that the gesture does not feel like a chore on a wide phone.
  static const _threshold = 0.82;

  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  /// Built once and disposed with the controller. Creating one per gesture
  /// leaks a ticker-mode listener, which surfaces as "looking up a deactivated
  /// widget's ancestor" the moment the screen is popped mid-animation.
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _settle,
    curve: Curves.easeOutCubic,
  );

  double _x = 0;
  double _travel = 1;
  double _from = 0;
  double _to = 0;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      setState(() => _x = _from + (_to - _from) * _curve.value);
    });
  }

  @override
  void didUpdateWidget(SlideAction old) {
    super.didUpdateWidget(old);
    // The caller finished and re-enabled the control: re-arm, and put the
    // thumb back where a fresh slide starts. Doing this in build() would be a
    // state mutation during layout.
    if (old.busy && !widget.busy) {
      _fired = false;
      _x = 0;
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _settle.dispose();
    super.dispose();
  }

  double get _progress => (_x / _travel).clamp(0.0, 1.0);

  bool get _interactive => widget.enabled && !widget.busy;

  void _animateTo(double target) {
    _from = _x;
    _to = target;
    _settle.forward(from: 0);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_interactive) return;
    setState(() => _x = (_x + d.delta.dx).clamp(0.0, _travel));
  }

  void _onDragEnd(DragEndDetails _) {
    if (!_interactive) return;

    if (_progress >= _threshold) {
      // Snap to the end and fire. The thumb stays there while the caller
      // works, so the control reads as "sent" rather than springing back to
      // look untouched.
      _animateTo(_travel);
      if (!_fired) {
        _fired = true;
        HapticFeedback.mediumImpact();
        widget.onConfirm();
      }
      return;
    }

    _animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final thumb = widget.height - 8;
    final label = widget.busy
        ? (widget.busyLabel ?? widget.label)
        : widget.label;
    final track = widget.color ?? AppColors.primary;

    return Semantics(
      button: true,
      enabled: _interactive,
      label: label,
      // Assistive tech cannot perform a drag, so activation is offered as a
      // plain tap here. The friction is for thumbs, not for screen readers.
      onTap: _interactive
          ? () {
              _fired = true;
              HapticFeedback.mediumImpact();
              widget.onConfirm();
            }
          : null,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _travel = (constraints.maxWidth - thumb - 8).clamp(1.0, 4000.0);
            // Busy parks the thumb at the end without writing to _x, so the
            // resting position is still there when the caller comes back.
            final x = widget.busy ? _travel : _x.clamp(0.0, _travel);

            return Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: widget.enabled ? track : track.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // The label fades as the thumb covers the track — by the
                  // time it matters, the gesture is telling the story.
                  Positioned.fill(
                    child: Center(
                      child: Opacity(
                        opacity: widget.busy
                            ? 1
                            : (1 - _progress * 1.4).clamp(0.0, 1.0),
                        child: Padding(
                          // The label centres in whatever the thumb is not
                          // covering, and the thumb changes ends when busy.
                          padding: widget.busy
                              ? EdgeInsets.only(right: thumb)
                              : EdgeInsets.only(left: thumb),
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4 + x,
                    top: 4,
                    child: GestureDetector(
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      child: Container(
                        width: thumb,
                        height: thumb,
                        decoration: const BoxDecoration(
                          color: AppColors.onPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: widget.busy
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      track,
                                    ),
                                    backgroundColor: track.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                )
                              : Icon(widget.icon, size: 20, color: track),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
