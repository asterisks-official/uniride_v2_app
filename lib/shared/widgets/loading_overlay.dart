import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'uni_loader.dart';

enum LoadingPhase { busy, success }

@immutable
class AppLoadingStatus {
  const AppLoadingStatus(this.message, this.phase);

  final String message;
  final LoadingPhase phase;

  @override
  bool operator ==(Object other) =>
      other is AppLoadingStatus &&
      other.message == message &&
      other.phase == phase;

  @override
  int get hashCode => Object.hash(message, phase);
}

/// Drives the app-wide loading HUD.
///
/// A spinner inside a button tells you the button was pressed; it does not tell
/// you the screen is busy, and it does not stop a second tap landing on
/// something else mid-request. This blurs and blocks the whole screen for the
/// duration, which is what iOS does for work you cannot navigate away from.
class AppLoadingController extends Notifier<AppLoadingStatus?> {
  /// Nested [run] calls share one HUD — only the outermost takes it down.
  int _depth = 0;

  @override
  AppLoadingStatus? build() => null;

  /// Runs [action] behind the HUD. Errors propagate untouched, so existing
  /// `try/catch` around the call site keeps working.
  Future<T> run<T>(
    Future<T> Function() action, {
    required String message,
    String? successMessage,
    Duration successHold = const Duration(milliseconds: 700),
  }) async {
    _depth++;
    state = AppLoadingStatus(message, LoadingPhase.busy);
    try {
      final result = await action();
      if (successMessage != null) {
        state = AppLoadingStatus(successMessage, LoadingPhase.success);
        await HapticFeedback.mediumImpact();
        await Future<void>.delayed(successHold);
      }
      return result;
    } finally {
      if (--_depth == 0) state = null;
    }
  }

  /// Retitles the HUD mid-flight, for work that runs in visible stages
  /// ("Uploading documents 2 of 4"). Ignored when nothing is running.
  void report(String message) {
    if (_depth > 0) state = AppLoadingStatus(message, LoadingPhase.busy);
  }
}

final appLoadingProvider =
    NotifierProvider<AppLoadingController, AppLoadingStatus?>(
      AppLoadingController.new,
    );

/// Mounts the HUD above the navigator. Install once, in `MaterialApp.builder`,
/// so the overlay survives route changes — a login that succeeds navigates
/// away while the HUD is still up, and it should fade out over the new screen
/// rather than vanish with the old one.
class AppLoadingScope extends ConsumerWidget {
  const AppLoadingScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        child,
        _LoadingHud(status: ref.watch(appLoadingProvider)),
      ],
    );
  }
}

class _LoadingHud extends StatefulWidget {
  const _LoadingHud({required this.status});

  final AppLoadingStatus? status;

  @override
  State<_LoadingHud> createState() => _LoadingHudState();
}

class _LoadingHudState extends State<_LoadingHud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 170),
  );

  /// Held so the card still has something to render on the way out.
  AppLoadingStatus? _last;

  @override
  void initState() {
    super.initState();
    _last = widget.status;
    if (widget.status != null) _ctrl.value = 1;
  }

  @override
  void didUpdateWidget(covariant _LoadingHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != null) {
      _last = widget.status;
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status ?? _last;
    if (status == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        if (_ctrl.isDismissed) return const SizedBox.shrink();
        final t = Curves.easeOutCubic.transform(_ctrl.value);

        return AbsorbPointer(
          absorbing: widget.status != null,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16 * t, sigmaY: 16 * t),
                child: ColoredBox(
                  color: AppColors.dark.withValues(alpha: 0.30 * t),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.88 + 0.12 * t,
                    child: _HudCard(status: status),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HudCard extends StatelessWidget {
  const _HudCard({required this.status});

  final AppLoadingStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 156, maxWidth: 268),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.22),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            width: 44,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: status.phase == LoadingPhase.success
                  ? const AnimatedCheckmark(
                      key: ValueKey('done'),
                      size: 44,
                      color: AppColors.success,
                    )
                  : const Center(
                      key: ValueKey('busy'),
                      child: UniLoader(size: 44, color: AppColors.primary),
                    ),
            ),
          ),
          const SizedBox(height: 15),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              status.message,
              key: ValueKey(status.message),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A checkmark that draws itself on, inside a ring that scales in behind it.
class AnimatedCheckmark extends StatefulWidget {
  const AnimatedCheckmark({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth,
  });

  final double size;
  final Color color;
  final double? strokeWidth;

  @override
  State<AnimatedCheckmark> createState() => _AnimatedCheckmarkState();
}

class _AnimatedCheckmarkState extends State<AnimatedCheckmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // The ring lands first, then the tick is drawn through it.
        final ring = Curves.easeOutBack.transform(
          (_ctrl.value / 0.45).clamp(0.0, 1.0),
        );
        final tick = Curves.easeOutCubic.transform(
          ((_ctrl.value - 0.3) / 0.7).clamp(0.0, 1.0),
        );
        return SizedBox(
          height: widget.size,
          width: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ring,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.12),
                  ),
                ),
              ),
              CustomPaint(
                size: Size.square(widget.size),
                painter: _CheckPainter(
                  progress: tick,
                  color: widget.color,
                  strokeWidth: widget.strokeWidth ?? widget.size * 0.11,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final path = Path()
      ..moveTo(size.width * 0.26, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.70)
      ..lineTo(size.width * 0.76, size.height * 0.33);

    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    final target = total * progress;

    final drawn = Path();
    var consumed = 0.0;
    for (final metric in metrics) {
      if (consumed >= target) break;
      drawn.addPath(
        metric.extractPath(0, math.min(metric.length, target - consumed)),
        Offset.zero,
      );
      consumed += metric.length;
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
