import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// One action the applicant is asked to perform on camera.
enum LivenessStep {
  blink,
  smile,

  /// Turn the head past a yaw threshold in either direction.
  turnAside,

  /// Turn past the same threshold the *opposite* way.
  turnBack,
}

enum LivenessPhase {
  /// No usable face yet, or it is too small / off-centre to work with.
  findFace,

  /// A face is framed and the user is working through the checks.
  challenge,

  /// Every check passed. Ready to capture.
  complete,
}

/// What the UI should show after feeding one frame.
class LivenessUpdate {
  const LivenessUpdate({
    required this.phase,
    required this.prompt,
    required this.progress,
    this.step,
    this.hint,
    this.advanced = false,
  });

  final LivenessPhase phase;
  final LivenessStep? step;

  /// The instruction, large and on its own.
  final String prompt;

  /// Secondary line — why nothing is happening, usually.
  final String? hint;

  /// 0–1 across all checks, for the ring around the viewfinder.
  final double progress;

  /// A check passed on this exact frame. Fire a haptic, once.
  final bool advanced;
}

/// Decides whether the face in front of the camera belongs to a live person.
///
/// A photo held up to the lens passes a "is there a face" test trivially, so
/// the applicant is asked to *do* things — blink, smile, turn each way — and
/// each must be observed as a change of state, not merely as a value. A print
/// of someone mid-smile never transitions from not-smiling to smiling, so it
/// cannot satisfy the smile check no matter how long it is held up.
///
/// The order is shuffled per attempt so a pre-recorded video of a real person
/// performing the actions cannot be replayed against a known sequence.
///
/// Pure logic, no camera or widget dependencies, so the thresholds below can be
/// exercised directly in tests.
class LivenessEngine {
  LivenessEngine({math.Random? random})
      : _random = random ?? math.Random(),
        _steps = const [] {
    reset();
  }

  // Framing gates. The face has to fill enough of the frame that ML Kit's
  // classifiers are reliable — eye-open probability is noisy on a small face.
  static const _minFaceWidthRatio = 0.26;
  static const _maxFaceWidthRatio = 0.92;
  static const _centreTolerance = 0.26;

  /// Frames a well-framed face must persist before the checks start, so the
  /// first prompt doesn't flash up while the user is still raising the phone.
  static const _framesToSettle = 5;

  // Classifier thresholds. Deliberately asymmetric: the "before" state is easy
  // to hit and the "after" state is strict, which is what makes each check a
  // transition rather than a reading.
  static const _eyesOpen = 0.55;
  static const _eyesShut = 0.22;
  static const _notSmiling = 0.35;
  static const _smiling = 0.70;
  static const _yawThreshold = 22.0;

  final math.Random _random;

  List<LivenessStep> _steps;
  int _index = 0;
  int _settledFrames = 0;

  // Per-check transition memory.
  bool _sawEyesOpen = false;
  bool _sawNeutralMouth = false;
  double? _asideSign;

  List<LivenessStep> get steps => List.unmodifiable(_steps);
  int get stepIndex => _index;
  bool get isComplete => _index >= _steps.length;

  void reset() {
    _steps = _shuffle();
    _index = 0;
    _settledFrames = 0;
    _sawEyesOpen = false;
    _sawNeutralMouth = false;
    _asideSign = null;
  }

  /// The turn pair moves as a unit — "now the other side" only reads as an
  /// instruction directly after the first turn.
  List<LivenessStep> _shuffle() {
    final units = <List<LivenessStep>>[
      [LivenessStep.blink],
      [LivenessStep.smile],
      [LivenessStep.turnAside, LivenessStep.turnBack],
    ]..shuffle(_random);
    return [for (final unit in units) ...unit];
  }

  /// Feeds one detection result. [imageSize] must already account for rotation
  /// — ML Kit reports face bounds in the upright image's coordinate space.
  LivenessUpdate update(Face? face, Size imageSize) {
    if (isComplete) {
      return const LivenessUpdate(
        phase: LivenessPhase.complete,
        prompt: 'Face verified',
        progress: 1,
      );
    }

    if (face == null) {
      _settledFrames = 0;
      return _framingUpdate('Position your face in the circle');
    }

    final framing = _framingProblem(face.boundingBox, imageSize);
    if (framing != null) {
      _settledFrames = 0;
      return _framingUpdate(framing);
    }

    if (_settledFrames < _framesToSettle) {
      _settledFrames++;
      return _framingUpdate('Hold still', hint: 'Looking for your face…');
    }

    final step = _steps[_index];
    final passed = switch (step) {
      LivenessStep.blink => _checkBlink(face),
      LivenessStep.smile => _checkSmile(face),
      LivenessStep.turnAside => _checkTurnAside(face),
      LivenessStep.turnBack => _checkTurnBack(face),
    };

    if (!passed) {
      return LivenessUpdate(
        phase: LivenessPhase.challenge,
        step: step,
        prompt: promptFor(step),
        hint: hintFor(step),
        progress: _index / _steps.length,
      );
    }

    _index++;
    _sawEyesOpen = false;
    _sawNeutralMouth = false;

    if (isComplete) {
      return const LivenessUpdate(
        phase: LivenessPhase.complete,
        prompt: 'Face verified',
        progress: 1,
        advanced: true,
      );
    }

    final next = _steps[_index];
    return LivenessUpdate(
      phase: LivenessPhase.challenge,
      step: next,
      prompt: promptFor(next),
      hint: hintFor(next),
      progress: _index / _steps.length,
      advanced: true,
    );
  }

  LivenessUpdate _framingUpdate(String prompt, {String? hint}) {
    return LivenessUpdate(
      phase: LivenessPhase.findFace,
      step: isComplete ? null : _steps[_index],
      prompt: prompt,
      hint: hint,
      progress: _index / _steps.length,
    );
  }

  /// Returns a human-readable reason the face can't be used, or null if fine.
  String? _framingProblem(Rect box, Size imageSize) {
    if (imageSize.width <= 0 || imageSize.height <= 0) return null;

    final widthRatio = box.width / imageSize.width;
    if (widthRatio < _minFaceWidthRatio) return 'Move a little closer';
    if (widthRatio > _maxFaceWidthRatio) return 'Move back slightly';

    final dx = (box.center.dx / imageSize.width) - 0.5;
    final dy = (box.center.dy / imageSize.height) - 0.5;
    if (dx.abs() > _centreTolerance || dy.abs() > _centreTolerance) {
      return 'Centre your face in the circle';
    }
    return null;
  }

  bool _checkBlink(Face face) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    if (left == null || right == null) return false;

    if (left > _eyesOpen && right > _eyesOpen) {
      _sawEyesOpen = true;
      return false;
    }
    // Both eyes, so a wink or a half-closed lid doesn't count.
    return _sawEyesOpen && left < _eyesShut && right < _eyesShut;
  }

  bool _checkSmile(Face face) {
    final smiling = face.smilingProbability;
    if (smiling == null) return false;

    if (smiling < _notSmiling) {
      _sawNeutralMouth = true;
      return false;
    }
    return _sawNeutralMouth && smiling > _smiling;
  }

  bool _checkTurnAside(Face face) {
    final yaw = face.headEulerAngleY;
    if (yaw == null || yaw.abs() < _yawThreshold) return false;
    // Remember which way, so the follow-up must be the other way. Which
    // physical direction a positive yaw means depends on whether the platform
    // hands us a mirrored frame, which is why neither prompt says "left".
    _asideSign = yaw.sign;
    return true;
  }

  bool _checkTurnBack(Face face) {
    final yaw = face.headEulerAngleY;
    final aside = _asideSign;
    if (yaw == null || aside == null) return false;
    return yaw.abs() >= _yawThreshold && yaw.sign != aside;
  }

  static String promptFor(LivenessStep step) => switch (step) {
        LivenessStep.blink => 'Blink slowly',
        LivenessStep.smile => 'Now smile',
        LivenessStep.turnAside => 'Turn your head to one side',
        LivenessStep.turnBack => 'Now turn to the other side',
      };

  static String hintFor(LivenessStep step) => switch (step) {
        LivenessStep.blink => 'Keep looking at the camera',
        LivenessStep.smile => 'Show your teeth',
        LivenessStep.turnAside => 'Slowly, and keep your face in the circle',
        LivenessStep.turnBack => 'Slowly, all the way across',
      };
}
