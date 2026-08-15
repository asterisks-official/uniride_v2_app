import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:uniride_app/features/rider/domain/liveness_engine.dart';

const _imageSize = Size(480, 640);

/// A well-framed, neutral, forward-facing face — the baseline every test
/// perturbs one attribute of.
Face _face({
  double eyes = 0.9,
  double smile = 0.05,
  double yaw = 0,
  Rect? box,
}) {
  return Face(
    boundingBox: box ??
        Rect.fromCenter(
          center: const Offset(240, 320),
          width: 200,
          height: 240,
        ),
    landmarks: const {},
    contours: const {},
    headEulerAngleY: yaw,
    leftEyeOpenProbability: eyes,
    rightEyeOpenProbability: eyes,
    smilingProbability: smile,
  );
}

/// Pushes frames until [engine] leaves the settling phase.
void _settle(LivenessEngine engine) {
  for (var i = 0; i < 8; i++) {
    engine.update(_face(), _imageSize);
  }
}

/// Drives whatever check is currently in front of us to completion.
void _satisfy(LivenessEngine engine, LivenessStep step) {
  switch (step) {
    case LivenessStep.blink:
      engine.update(_face(eyes: 0.9), _imageSize);
      engine.update(_face(eyes: 0.05), _imageSize);
    case LivenessStep.smile:
      engine.update(_face(smile: 0.05), _imageSize);
      engine.update(_face(smile: 0.95), _imageSize);
    case LivenessStep.turnAside:
      engine.update(_face(yaw: 40), _imageSize);
    case LivenessStep.turnBack:
      engine.update(_face(yaw: -40), _imageSize);
  }
}

void main() {
  group('framing', () {
    test('asks for a face when none is detected', () {
      final engine = LivenessEngine(random: math.Random(1));
      final update = engine.update(null, _imageSize);

      expect(update.phase, LivenessPhase.findFace);
      expect(update.progress, 0);
    });

    test('asks the user to come closer when the face is too small', () {
      final engine = LivenessEngine(random: math.Random(1));
      final update = engine.update(
        _face(
          box: Rect.fromCenter(
            center: const Offset(240, 320),
            width: 60,
            height: 72,
          ),
        ),
        _imageSize,
      );

      expect(update.phase, LivenessPhase.findFace);
      expect(update.prompt, 'Move a little closer');
    });

    test('asks the user to centre an off-centre face', () {
      final engine = LivenessEngine(random: math.Random(1));
      final update = engine.update(
        _face(
          box: Rect.fromCenter(
            center: const Offset(60, 320),
            width: 200,
            height: 240,
          ),
        ),
        _imageSize,
      );

      expect(update.phase, LivenessPhase.findFace);
      expect(update.prompt, 'Centre your face in the circle');
    });

    test('does not start the checks until the face has held still', () {
      final engine = LivenessEngine(random: math.Random(1));
      final first = engine.update(_face(), _imageSize);

      expect(first.phase, LivenessPhase.findFace);
      expect(engine.stepIndex, 0);
    });
  });

  group('checks', () {
    test('a blink passes only after eyes were seen open', () {
      final engine = LivenessEngine(random: math.Random(1));
      _settle(engine);
      // Force the blink check to the front regardless of the shuffle.
      while (engine.steps[engine.stepIndex] != LivenessStep.blink) {
        _satisfy(engine, engine.steps[engine.stepIndex]);
      }
      final at = engine.stepIndex;

      // Shut eyes with no prior open frame — a photo of someone blinking.
      final closedOnly = LivenessEngine(random: math.Random(1));
      _settle(closedOnly);
      expect(closedOnly.update(_face(eyes: 0.9), _imageSize).advanced, isFalse);

      engine.update(_face(eyes: 0.9), _imageSize);
      final blinked = engine.update(_face(eyes: 0.05), _imageSize);

      expect(blinked.advanced, isTrue);
      expect(engine.stepIndex, at + 1);
    });

    test('a held smile does not pass — only a change to smiling does', () {
      final engine = LivenessEngine(random: math.Random(3));
      _settle(engine);
      while (engine.steps[engine.stepIndex] != LivenessStep.smile) {
        _satisfy(engine, engine.steps[engine.stepIndex]);
      }
      final at = engine.stepIndex;

      // Every frame already smiling: a printed photo of a smile.
      for (var i = 0; i < 10; i++) {
        engine.update(_face(smile: 0.95), _imageSize);
      }
      expect(engine.stepIndex, at, reason: 'no neutral frame was ever seen');

      engine.update(_face(smile: 0.05), _imageSize);
      final smiled = engine.update(_face(smile: 0.95), _imageSize);

      expect(smiled.advanced, isTrue);
      expect(engine.stepIndex, at + 1);
    });

    test('turning back the same way as the first turn does not pass', () {
      final engine = LivenessEngine(random: math.Random(2));
      _settle(engine);
      while (engine.steps[engine.stepIndex] != LivenessStep.turnAside) {
        _satisfy(engine, engine.steps[engine.stepIndex]);
      }

      engine.update(_face(yaw: 40), _imageSize);
      expect(engine.steps[engine.stepIndex], LivenessStep.turnBack);

      engine.update(_face(yaw: 45), _imageSize);
      expect(
        engine.steps[engine.stepIndex],
        LivenessStep.turnBack,
        reason: 'the same direction is not the other side',
      );

      final crossed = engine.update(_face(yaw: -45), _imageSize);
      expect(crossed.advanced, isTrue);
    });
  });

  group('run', () {
    test('completes once every check passes, in whatever order', () {
      for (var seed = 0; seed < 12; seed++) {
        final engine = LivenessEngine(random: math.Random(seed));
        _settle(engine);
        while (!engine.isComplete) {
          _satisfy(engine, engine.steps[engine.stepIndex]);
        }

        final update = engine.update(_face(), _imageSize);
        expect(update.phase, LivenessPhase.complete);
        expect(update.progress, 1);
      }
    });

    test('holds progress but stops advancing when the face leaves', () {
      final engine = LivenessEngine(random: math.Random(1));
      _settle(engine);
      _satisfy(engine, engine.steps[0]);
      final reached = engine.stepIndex;

      final lost = engine.update(null, _imageSize);

      expect(lost.phase, LivenessPhase.findFace);
      expect(engine.stepIndex, reached);
      expect(lost.progress, greaterThan(0));
    });

    test('reset clears progress and reshuffles', () {
      final engine = LivenessEngine(random: math.Random(1));
      _settle(engine);
      _satisfy(engine, engine.steps[0]);
      expect(engine.stepIndex, greaterThan(0));

      engine.reset();

      expect(engine.stepIndex, 0);
      expect(engine.steps.length, 4);
    });

    test('the turn pair always stays in order', () {
      for (var seed = 0; seed < 20; seed++) {
        final steps = LivenessEngine(random: math.Random(seed)).steps;
        expect(
          steps.indexOf(LivenessStep.turnBack),
          steps.indexOf(LivenessStep.turnAside) + 1,
        );
      }
    });
  });
}
