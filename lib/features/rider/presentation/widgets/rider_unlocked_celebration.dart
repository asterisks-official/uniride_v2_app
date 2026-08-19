import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';

/// The whole sequence runs off one controller of this length; every element
/// reads its own window out of it via [_stage].
///
/// Keeping the beats as absolute milliseconds in a single place is what lets
/// them be tuned against each other — a stamp that lands 200ms late is obvious
/// here and invisible when each piece owns its own controller.
const _sequence = Duration(milliseconds: 3400);

/// The rider lands, the seal stamps, everything else answers the stamp.
const _rideInStart = 340.0;
const _rideInEnd = 1180.0;
const _stampStart = 1150.0;
const _stampEnd = 1620.0;
const _confettiStart = 1400.0;
const _titleStart = 1620.0;
const _bodyStart = 1760.0;
const _actionsStart = 1980.0;

/// Progress through the window [startMs]–[endMs], eased by [curve].
double _stage(double value, double startMs, double endMs, Curve curve) =>
    curve.transform(
      ((value * _sequence.inMilliseconds - startMs) / (endMs - startMs))
          .clamp(0.0, 1.0),
    );

/// The moment an approved application becomes actual rider access.
///
/// Approval is the largest thing that happens to an account in this app: it is
/// the end of a four-step form, four document uploads and a face scan, and it
/// is the point where the account can start earning. A toast reading "rider
/// mode enabled" is the same acknowledgement a settings switch gets, and it
/// spends the one moment in the flow that people actually want to feel.
///
/// So it is played rather than reported — the app's own scooter illustration
/// rides in, a verified seal stamps onto it, and the confetti is thrown from
/// the point of impact. It skips on tap and settles into two plain choices, so
/// nobody who does not want the moment has to sit through it.
class RiderUnlockedCelebration extends StatefulWidget {
  const RiderUnlockedCelebration({super.key});

  /// Plays the celebration over the current screen.
  ///
  /// Resolves true if they asked to head straight into the app, and false or
  /// null if they dismissed it and stayed where they were.
  static Future<bool?> open(BuildContext context) {
    return Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        // Transparent: the screen underneath is the thing being blurred, and
        // it is also what they return to if they choose to stay.
        opaque: false,
        barrierColor: Colors.transparent,
        // No entrance transition — the widget runs its own, and a route fade
        // on top of it would only mute the first beat. The exit still fades,
        // because leaving on one frame reads as a crash.
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => const RiderUnlockedCelebration(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<RiderUnlockedCelebration> createState() =>
      _RiderUnlockedCelebrationState();
}

class _RiderUnlockedCelebrationState extends State<RiderUnlockedCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _sequence,
  );

  late final List<_Particle> _confetti = _buildConfetti();

  /// Fired off the controller rather than a timer, so a skip that jumps the
  /// sequence forward still gets its impact — exactly once.
  bool _stampFelt = false;

  bool _reduceMotion = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_maybeStamp);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Honour the system setting: someone who asked for less motion gets the
    // end state — illustration, seal and copy — without the travel or the
    // confetti.
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _ctrl.value = 1;
    } else {
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _maybeStamp() {
    if (_stampFelt || _ctrl.value * _sequence.inMilliseconds < _stampStart) {
      return;
    }
    _stampFelt = true;
    HapticFeedback.heavyImpact();
  }

  /// Tapping anywhere runs the rest of the sequence out fast. Impatience
  /// should land on the buttons, not on a screen that ignores it.
  void _skip() {
    if (_ctrl.isCompleted) return;
    _ctrl.animateTo(1, duration: const Duration(milliseconds: 420));
  }

  void _close({required bool leave}) => Navigator.of(context).pop(leave);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _skip,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final entrance = _stage(_ctrl.value, 0, 300, Curves.easeOut);

            return Stack(
              fit: StackFit.expand,
              children: [
                _Ground(entrance: entrance),
                SafeArea(
                  child: _Content(
                    progress: _ctrl.value,
                    confetti: _reduceMotion ? const [] : _confetti,
                    onStart: () => _close(leave: true),
                    onStay: () => _close(leave: false),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Ground ───────────────────────────────────────────────────────────────────

/// Blurs the screen underneath and lays a light wash over it.
///
/// Light rather than dark: the scooter illustration is drawn with near-black
/// outlines for a white page, and half of it disappears on a dark ground.
class _Ground extends StatelessWidget {
  const _Ground({required this.entrance});

  final double entrance;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 18 * entrance, sigmaY: 18 * entrance),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.35),
            radius: 1.1,
            colors: [
              AppColors.primaryWash.withValues(alpha: 0.98 * entrance),
              AppColors.surface.withValues(alpha: 0.98 * entrance),
              AppColors.background.withValues(alpha: 0.99 * entrance),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
      ),
    );
  }
}

// ── Hero, copy, actions ──────────────────────────────────────────────────────

class _Content extends StatelessWidget {
  const _Content({
    required this.progress,
    required this.confetti,
    required this.onStart,
    required this.onStay,
  });

  final double progress;

  /// Empty under reduced motion.
  final List<_Particle> confetti;

  final VoidCallback onStart;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    final title = _stage(
      progress,
      _titleStart,
      _titleStart + 460,
      Curves.easeOutCubic,
    );
    final body = _stage(
      progress,
      _bodyStart,
      _bodyStart + 460,
      Curves.easeOutCubic,
    );
    final actions = _stage(
      progress,
      _actionsStart,
      _actionsStart + 460,
      Curves.easeOutCubic,
    );

    const padding = EdgeInsets.fromLTRB(28, 24, 28, 28);

    return LayoutBuilder(
      builder: (context, constraints) {
        final inner = constraints.deflate(padding);

        // A scroll view rather than a fixed column: at a large system text
        // size the copy alone can outgrow a short screen, and a celebration
        // that ends in a yellow-and-black overflow bar is worse than no
        // celebration. It only actually scrolls when it has to.
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: inner.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Hero(
                  progress: progress,
                  confetti: confetti,
                  maxWidth: inner.maxWidth,
                  // A third of the viewport: big enough to be the subject,
                  // small enough that the copy and the buttons still fit
                  // above the fold on a small phone.
                  maxHeight: (inner.maxHeight * 0.34).clamp(132.0, 236.0),
                ),
                const SizedBox(height: 26),
                _Rise(
                  t: title,
                  child: const Text(
                    'You’re a rider now',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                      height: 1.15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _Rise(
                  t: body,
                  child: const Text(
                    'Rider mode is on. Post ride offers, pick your passengers '
                    'and start earning on trips you were already making.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _Actions(t: actions, onStart: onStart, onStay: onStay),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fades and lifts by a progress value someone else owns.
///
/// [FadeSlideIn] cannot do this job: it runs its own clock from first build,
/// and every beat here has to stay locked to the one sequence controller.
class _Rise extends StatelessWidget {
  const _Rise({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t == 1) return child;
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
    );
  }
}

/// The scooter rides in from the left, then the seal stamps onto it.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.progress,
    required this.confetti,
    required this.maxWidth,
    required this.maxHeight,
  });

  final double progress;
  final List<_Particle> confetti;
  final double maxWidth;
  final double maxHeight;

  /// The scooter artboard is 543×388. Sizing the hero box to that exact ratio
  /// — instead of letting [BoxFit.contain] letterbox inside a looser box — is
  /// what keeps the seal on the same spot of the drawing at every screen size.
  static const _artAspect = 543 / 388;

  /// Where the seal sits on the artwork, in the hero box's own coordinates:
  /// off the scooter's tail, clipping the rear wheel. Anywhere further in and
  /// it covers a rider's face; anywhere further out and it stops reading as
  /// stamped *onto* anything.
  static const _sealAt = Alignment(0.66, 0.60);

  @override
  Widget build(BuildContext context) {
    final width = math.min(maxWidth, maxHeight * _artAspect);
    final height = width / _artAspect;

    final ride = _stage(
      progress,
      _rideInStart,
      _rideInEnd,
      Curves.easeOutCubic,
    );
    // Arrives before it settles: the fade finishes at two-thirds of the travel
    // so it is fully drawn while still visibly moving.
    final fade = (ride * 1.5).clamp(0.0, 1.0);
    final stamp = _stage(progress, _stampStart, _stampEnd, Curves.easeOutBack);
    final glow = _stage(
      progress,
      _stampStart,
      _stampStart + 700,
      Curves.easeOut,
    );

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Bloom timed to the impact rather than the arrival — it reads as
          // the seal lighting the scene up.
          Opacity(
            opacity: glow * 0.5,
            child: Container(
              height: height * 1.05,
              width: height * 1.05,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.30),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Opacity(
            opacity: fade,
            child: Transform.translate(
              offset: Offset(-width * 0.55 * (1 - ride), 0),
              child: Lottie.asset(
                'assets/animations/scooter.json',
                width: width,
                height: height,
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
          ),
          Align(
            alignment: _sealAt,
            child: _VerifiedSeal(
              progress: progress,
              stamp: stamp,
              size: (height * 0.30).clamp(46.0, 66.0),
            ),
          ),
          if (confetti.isNotEmpty)
            Positioned.fill(
              child: IgnorePointer(
                // Deliberately painting outside its own bounds: the burst is
                // anchored to the seal and has to cross the whole screen, and
                // this is the only box that knows where the seal ended up. The
                // scroll viewport above is what clips it, at the screen edge.
                child: CustomPaint(
                  painter: _ConfettiPainter(
                    particles: confetti,
                    t: _stage(
                      progress,
                      _confettiStart,
                      _sequence.inMilliseconds.toDouble(),
                      Curves.linear,
                    ),
                    origin: Offset(
                      (_sealAt.x + 1) / 2 * width,
                      (_sealAt.y + 1) / 2 * height,
                    ),
                    unit: MediaQuery.sizeOf(context).shortestSide,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A verified disc that drops in oversized and lands at full size, throwing
/// two shockwave rings out as it hits.
class _VerifiedSeal extends StatelessWidget {
  const _VerifiedSeal({
    required this.progress,
    required this.stamp,
    required this.size,
  });

  final double progress;

  /// Eased with [Curves.easeOutBack], so it overshoots past 1 and settles.
  final double stamp;

  final double size;

  @override
  Widget build(BuildContext context) {
    if (stamp == 0) return SizedBox.square(dimension: size);

    // 2.6 → 1: coming down onto the page rather than growing out of it.
    final scale = 2.6 - 1.6 * stamp;
    final tick = _stage(
      progress,
      _stampEnd - 120,
      _stampEnd + 320,
      Curves.easeOutCubic,
    );

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (final delay in const [0.0, 160.0])
            _Shockwave(
              t: _stage(
                progress,
                _stampEnd + delay,
                _stampEnd + delay + 620,
                Curves.easeOutCubic,
              ),
              size: size,
            ),
          Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: (stamp * 2.4).clamp(0.0, 1.0),
              child: Container(
                // Sized explicitly: a CustomPaint with neither a size nor a
                // child lays out at zero, which collapses the disc around it
                // to a speck.
                height: size,
                width: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: AppColors.surface, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.38),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CustomPaint(
                  size: Size.square(size),
                  painter: _TickPainter(progress: tick),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shockwave extends StatelessWidget {
  const _Shockwave({required this.t, required this.size});

  final double t;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (t == 0 || t == 1) return const SizedBox.shrink();
    return Transform.scale(
      scale: 1 + t * 1.5,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.45 * (1 - t)),
            width: 2.5 * (1 - t),
          ),
        ),
      ),
    );
  }
}

/// Strokes a tick on, in the order a hand would draw it.
class _TickPainter extends CustomPainter {
  const _TickPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final path = Path()
      ..moveTo(size.width * 0.29, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.68)
      ..lineTo(size.width * 0.73, size.height * 0.34);

    final drawn = Path();
    for (final metric in path.computeMetrics()) {
      drawn.addPath(
        metric.extractPath(0, metric.length * progress),
        Offset.zero,
      );
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..color = AppColors.onPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress;
}

// ── Actions ──────────────────────────────────────────────────────────────────

class _Actions extends StatelessWidget {
  const _Actions({
    required this.t,
    required this.onStart,
    required this.onStay,
  });

  final double t;
  final VoidCallback onStart;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      // Nothing to press until they have arrived: a tap during the sequence is
      // a skip, and it must not also dispatch whatever the skip drops under
      // the finger a frame later.
      ignoring: t < 1,
      child: _Rise(
        t: t,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton(
                label: 'Start riding',
                icon: Icons.two_wheeler_rounded,
                onPressed: onStart,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Stay here',
                variant: AppButtonVariant.outline,
                onPressed: onStay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Confetti ─────────────────────────────────────────────────────────────────

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.length,
    required this.width,
    required this.spin,
    required this.spinRate,
    required this.delay,
    required this.color,
  });

  /// Radians from the +x axis, biased upward on generation.
  final double angle;

  /// Peak travel, as a fraction of the screen's short side.
  final double speed;

  final double length;
  final double width;
  final double spin;
  final double spinRate;

  /// Fraction of the burst window to wait before launching, so the throw has a
  /// leading edge instead of every scrap appearing on one frame.
  final double delay;

  final Color color;
}

/// Brand greens, plus the illustration's own purple and coral.
///
/// Sampling the scooter's palette is what stops the confetti reading as a
/// separate effect pasted over somebody else's artwork.
const _confettiColors = [
  AppColors.primary,
  AppColors.primaryDark,
  AppColors.success,
  AppColors.warning,
  Color(0xFF614CD4),
  Color(0xFFFF8C71),
];

/// Seeded, so the burst is identical on every run — a shape worth tuning is a
/// shape worth being able to look at twice.
List<_Particle> _buildConfetti() {
  const count = 46;
  final rand = math.Random(7);
  return List.generate(count, (i) {
    // Fans up and out over -170°..-10°, so nothing is thrown straight down.
    //
    // Stratified rather than uniformly random: 46 independent draws leave
    // visible clumps and bald patches on one side, and the burst has to look
    // thrown, not sprayed. The jitter inside each slice is what keeps it from
    // looking combed.
    final slice = (i + 0.15 + 0.7 * rand.nextDouble()) / count;
    final angle = -math.pi * (0.06 + 0.88 * slice);
    return _Particle(
      angle: angle,
      speed: 0.34 + 0.52 * rand.nextDouble(),
      length: 7 + 8 * rand.nextDouble(),
      width: 3 + 3 * rand.nextDouble(),
      spin: rand.nextDouble() * math.pi * 2,
      spinRate: (rand.nextDouble() * 2 - 1) * 7,
      delay: rand.nextDouble() * 0.14,
      color: _confettiColors[i % _confettiColors.length],
    );
  });
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.particles,
    required this.t,
    required this.origin,
    required this.unit,
  });

  final List<_Particle> particles;

  /// 0→1 across the burst window.
  final double t;

  /// Where the seal landed, in this canvas's coordinates.
  final Offset origin;

  /// Screen short side — travel is scaled to the device, not to this box,
  /// which is a good deal smaller than the distance the scraps cover.
  final double unit;

  /// Drag normaliser: without it a stiffer drag would also mean a shorter
  /// throw, and the two want tuning separately.
  static const _drag = 3.4;
  static final _dragNorm = 1 - math.exp(-_drag);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;

    final paint = Paint();

    for (final p in particles) {
      final life = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (life <= 0) continue;

      // Thrown hard and slowed: nearly all the distance is covered in the
      // first third, which is what separates a burst from a drift.
      final travel = p.speed * (1 - math.exp(-_drag * life)) / _dragNorm;
      final fall = 1.15 * life * life;

      // In over the first breath, out over the last third.
      final opacity =
          (life / 0.08).clamp(0.0, 1.0) *
          (1 - ((life - 0.62) / 0.38).clamp(0.0, 1.0));
      if (opacity <= 0) continue;

      canvas.save();
      canvas.translate(
        origin.dx + math.cos(p.angle) * travel * unit,
        origin.dy + (math.sin(p.angle) * travel + fall) * unit,
      );
      canvas.rotate(p.spin + p.spinRate * life);
      // Squashed on one axis as it turns, so the scraps read as flat paper
      // flipping over rather than as pills.
      final flip = p.spin * 2 + p.spinRate * life * 2;
      canvas.scale(1, math.cos(flip).abs() * 0.8 + 0.2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.length, height: p.width),
          Radius.circular(p.width / 2),
        ),
        paint..color = p.color.withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) =>
      old.t != t || old.origin != origin || old.unit != unit;
}
