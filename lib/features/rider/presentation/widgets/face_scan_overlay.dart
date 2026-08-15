import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Darkens everything outside an oval viewfinder and draws the progress ring
/// around it.
///
/// The cutout is the whole point: it tells the applicant where to put their
/// face far more directly than any instruction, and the ring turns four
/// invisible checks into one visible thing filling up.
class FaceScanOverlay extends StatelessWidget {
  const FaceScanOverlay({
    super.key,
    required this.cutout,
    required this.progress,
    required this.pulse,
    required this.ringColor,
    this.scrimColor = const Color(0xE6121917),
  });

  /// Viewfinder bounds, in the overlay's own coordinate space.
  final Rect cutout;

  /// 0–1 across all liveness checks.
  final double progress;

  /// 0–1 breathing animation, used only while nothing has been proved yet.
  final double pulse;

  final Color ringColor;
  final Color scrimColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _FaceScanPainter(
        cutout: cutout,
        progress: progress,
        pulse: pulse,
        ringColor: ringColor,
        scrimColor: scrimColor,
      ),
    );
  }
}

class _FaceScanPainter extends CustomPainter {
  const _FaceScanPainter({
    required this.cutout,
    required this.progress,
    required this.pulse,
    required this.ringColor,
    required this.scrimColor,
  });

  final Rect cutout;
  final double progress;
  final double pulse;
  final Color ringColor;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addOval(cutout),
      ),
      Paint()..color = scrimColor,
    );

    final track = cutout.inflate(11);

    // A halo that breathes outward while the ring is still empty — the screen
    // has to look alive before the user has done anything to make it move.
    if (progress < 1) {
      canvas.drawOval(
        track.inflate(4 + 14 * pulse),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = ringColor.withValues(alpha: 0.35 * (1 - pulse)),
      );
    }

    canvas.drawOval(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    if (progress > 0) {
      canvas.drawArc(
        track,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round
          ..color = ringColor,
      );
    }
  }

  @override
  bool shouldRepaint(_FaceScanPainter old) =>
      old.cutout != cutout ||
      old.progress != progress ||
      old.pulse != pulse ||
      old.ringColor != ringColor ||
      old.scrimColor != scrimColor;
}
