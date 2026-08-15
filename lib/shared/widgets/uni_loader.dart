import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/theme/app_theme.dart';

/// The app's spinner.
///
/// A comet sweeping a circular track: the arc grows from its head, then the
/// tail catches up, while the whole thing rotates. Two motions at different
/// rates is what stops it reading as a plain rotating dash — and the gradient
/// gives the head weight, so the eye follows the direction of travel.
///
/// Sized for anything from a 20px button spinner to a 96px splash mark.
class UniLoader extends StatefulWidget {
  const UniLoader({
    super.key,
    this.size = 44,
    this.color,
    this.trackColor,
    this.strokeWidth,
    this.glyph,
  });

  final double size;
  final Color? color;

  /// The faint ring the comet travels along. Null draws it from [color].
  final Color? trackColor;

  final double? strokeWidth;

  /// Optional mark in the middle — used on the splash, omitted everywhere else.
  final Widget? glyph;

  @override
  State<UniLoader> createState() => _UniLoaderState();
}

class _UniLoaderState extends State<UniLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    final stroke = widget.strokeWidth ?? math.max(2.0, widget.size * 0.085);

    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _CometPainter(
                t: _ctrl.value,
                color: color,
                trackColor: widget.trackColor ?? color.withValues(alpha: 0.13),
                strokeWidth: stroke,
              ),
            ),
          ),
          if (widget.glyph != null) widget.glyph!,
        ],
      ),
    );
  }
}

class _CometPainter extends CustomPainter {
  const _CometPainter({
    required this.t,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double t;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = rect.deflate(strokeWidth / 2);

    canvas.drawArc(
      circle,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    // Head runs ahead over the first half of the cycle, tail closes over the
    // second. Easing both means the arc never snaps between the two phases.
    final head = Curves.easeInOutCubic.transform(math.min(t * 2, 1.0));
    final tail = Curves.easeInOutCubic.transform(math.max(t * 2 - 1, 0.0));

    const minSweep = 0.12;
    const maxSweep = 0.78;
    final sweep = (minSweep + (head - tail) * maxSweep) * 2 * math.pi;
    final start = (t * 1.6 + tail * 0.9) * 2 * math.pi - math.pi / 2;

    // Fading the tail out is what makes it a comet rather than a dash. The
    // gradient rotates with the arc, so the bright end is always the head.
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: sweep,
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.55),
        color,
      ],
      stops: const [0.0, 0.55, 1.0],
      transform: GradientRotation(start),
    ).createShader(rect);

    canvas.drawArc(
      circle,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );

    // A dot on the head, so the leading edge stays crisp at small sizes where
    // the gradient has too few pixels to read.
    final headAngle = start + sweep;
    final radius = circle.width / 2;
    canvas.drawCircle(
      circle.center +
          Offset(math.cos(headAngle) * radius, math.sin(headAngle) * radius),
      strokeWidth / 2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CometPainter old) =>
      old.t != t ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// Three dots rising and falling in sequence.
///
/// For places where a ring would compete with surrounding circular shapes —
/// inline in a row of text, or under a piece of content that is already busy.
class UniDots extends StatefulWidget {
  const UniDots({super.key, this.size = 7, this.color, this.gap = 5});

  final double size;
  final Color? color;
  final double gap;

  @override
  State<UniDots> createState() => _UniDotsState();
}

class _UniDotsState extends State<UniDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i != 0) SizedBox(width: widget.gap),
            Builder(
              builder: (context) {
                // Each dot lags the one before it by a third of the cycle.
                final phase = (_ctrl.value - i * 0.16) % 1.0;
                final lift = math.sin(phase * math.pi).clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset(0, -lift * widget.size * 0.7),
                  child: Container(
                    height: widget.size,
                    width: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.4 + 0.6 * lift),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
