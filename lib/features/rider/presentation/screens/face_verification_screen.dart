import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../domain/liveness_engine.dart';
import '../widgets/face_scan_overlay.dart';

/// Degrees the device is rotated from its natural orientation. Needed to work
/// out how far the sensor frame has to be turned before ML Kit sees it upright.
const _deviceRotationDegrees = <DeviceOrientation, int>{
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// How long one prompt may go unanswered before the run restarts.
const _stepTimeout = Duration(seconds: 25);

/// Live selfie capture with liveness checks.
///
/// Pops with the captured [XFile], or null if the applicant backed out.
class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key});

  static Future<XFile?> open(BuildContext context) {
    return Navigator.of(context).push<XFile>(
      MaterialPageRoute<XFile>(
        fullscreenDialog: true,
        builder: (_) => const FaceVerificationScreen(),
      ),
    );
  }

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _engine = LivenessEngine();
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      // Eye-open and smile probabilities — without these there is nothing to
      // test but "a face exists", which a printed photo satisfies.
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  CameraController? _controller;
  CameraDescription? _camera;

  /// One frame in flight at a time. Detection is slower than the stream, and
  /// queueing frames only makes the prompts lag behind the user.
  bool _detecting = false;
  bool _capturing = false;
  bool _starting = true;
  String? _fatalError;

  /// Overrides the prompt briefly after a restart, so the message is readable
  /// instead of being overwritten by the very next frame.
  String? _notice;
  Timer? _noticeTimer;
  Timer? _stepTimer;

  LivenessUpdate _update = const LivenessUpdate(
    phase: LivenessPhase.findFace,
    prompt: 'Position your face in the circle',
    progress: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepTimer?.cancel();
    _noticeTimer?.cancel();
    _pulse.dispose();
    _controller?.dispose();
    _detector.close();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        _fatalError == null &&
        // The permission dialog itself backgrounds the app, so a resume can
        // land while the first _start() is still awaiting initialize().
        !_starting &&
        !_capturing) {
      _start();
    }
  }

  // ── Camera lifecycle ───────────────────────────────────────────────────────

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _fatalError = null;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail('This device has no camera we can use.');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        camera,
        // Detection accuracy plateaus well below full resolution, and a smaller
        // frame is the difference between prompts that keep up and prompts that
        // arrive a second late.
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _engine.reset();
      setState(() {
        _camera = camera;
        _controller = controller;
        _starting = false;
        _update = const LivenessUpdate(
          phase: LivenessPhase.findFace,
          prompt: 'Position your face in the circle',
          progress: 0,
        );
      });
      await controller.startImageStream(_onFrame);
      _restartStepTimer();
    } on CameraException catch (e) {
      _fail(switch (e.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' =>
          'UniRide needs camera access to verify your face. Enable it in '
              'Settings, then try again.',
        _ => e.description ?? 'The camera could not be started.',
      });
    } catch (_) {
      _fail('The camera could not be started.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _fatalError = message;
      _starting = false;
    });
  }

  void _stopCamera() {
    final controller = _controller;
    if (controller == null) return;
    _stepTimer?.cancel();
    setState(() => _controller = null);
    controller.dispose();
  }

  // ── Detection ──────────────────────────────────────────────────────────────

  Future<void> _onFrame(CameraImage image) async {
    if (_detecting || _capturing || !mounted) return;
    _detecting = true;
    try {
      final rotation = _rotationFor(image);
      if (rotation == null) return;
      final input = _toInputImage(image, rotation);
      if (input == null) return;

      final faces = await _detector.processImage(input);
      if (!mounted || _capturing) return;

      // Exactly one face. Two is ambiguous, and it is also the shape of
      // someone holding a photo of another person up beside their own head.
      _applyDetection(
        faces.length == 1 ? faces.first : null,
        _uprightSize(image, rotation),
      );
    } catch (_) {
      // A dropped frame is not worth surfacing — the next one is milliseconds
      // away, and an error toast here would fire dozens of times a second.
    } finally {
      _detecting = false;
    }
  }

  InputImageRotation? _rotationFor(CameraImage image) {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    }

    final deviceRotation =
        _deviceRotationDegrees[controller.value.deviceOrientation];
    if (deviceRotation == null) return null;

    // The front sensor is mirrored relative to the back one, so its rotation
    // compensates in the opposite direction.
    final compensated = camera.lensDirection == CameraLensDirection.front
        ? (camera.sensorOrientation + deviceRotation) % 360
        : (camera.sensorOrientation - deviceRotation + 360) % 360;
    return InputImageRotationValue.fromRawValue(compensated);
  }

  InputImage? _toInputImage(CameraImage image, InputImageRotation rotation) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // nv21 on Android and bgra8888 on iOS both arrive as a single plane, which
    // is the only layout InputImage.fromBytes can describe.
    if (format == null || image.planes.length != 1) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Face bounds come back in the *rotated* image's space, so the size they are
  /// measured against has to be rotated to match.
  Size _uprightSize(CameraImage image, InputImageRotation rotation) {
    final quarterTurned =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    return quarterTurned
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());
  }

  void _applyDetection(Face? face, Size imageSize) {
    final update = _engine.update(face, imageSize);
    if (update.advanced) {
      HapticFeedback.lightImpact();
      _restartStepTimer();
    }
    setState(() => _update = update);
    if (update.phase == LivenessPhase.complete) _capture();
  }

  void _restartStepTimer() {
    _stepTimer?.cancel();
    if (_engine.isComplete) return;
    _stepTimer = Timer(_stepTimeout, _restartRun);
  }

  void _restartRun() {
    if (!mounted || _capturing) return;
    _engine.reset();
    _showNotice("Let's start that again");
    _restartStepTimer();
  }

  void _showNotice(String message) {
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  // ── Capture ────────────────────────────────────────────────────────────────

  Future<void> _capture() async {
    if (_capturing) return;
    _capturing = true;
    _stepTimer?.cancel();
    HapticFeedback.mediumImpact();

    final controller = _controller;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      // Let the ring finish closing before the shutter. Freezing mid-animation
      // reads as a crash, not as success.
      await Future<void>.delayed(const Duration(milliseconds: 550));
      final shot = await controller.takePicture();
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      Navigator.of(context).pop(shot);
    } on CameraException catch (e) {
      _capturing = false;
      _fail(e.description ?? 'The photo could not be taken.');
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final done = _update.phase == LivenessPhase.complete;
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: _fatalError != null
          ? _CameraError(message: _fatalError!, onRetry: _start)
          : LayoutBuilder(
              builder: (context, constraints) {
                final cutout = _cutoutFor(constraints.biggest);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _preview(constraints.biggest),
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => FaceScanOverlay(
                        cutout: cutout,
                        progress: _update.progress,
                        pulse: _pulse.value,
                        ringColor: done ? AppColors.success : AppColors.primary,
                      ),
                    ),
                    if (done)
                      Positioned.fromRect(
                        rect: cutout,
                        child: const Center(
                          child: AnimatedCheckmark(
                            size: 92,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    _topBar(),
                    _prompts(cutout, constraints.biggest),
                  ],
                );
              },
            ),
    );
  }

  /// An upright oval a little above centre — where a face naturally sits when
  /// someone holds a phone at reading height.
  Rect _cutoutFor(Size size) {
    final width = (size.width * 0.72).clamp(200.0, 300.0);
    final height = width * 1.3;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.40),
      width: width,
      height: height,
    );
  }

  Widget _preview(Size available) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: _starting
            ? const CircularProgressIndicator(color: Colors.white38)
            : const SizedBox.shrink(),
      );
    }

    // CameraPreview sizes itself to the sensor's aspect ratio and letterboxes
    // inside whatever box it is given; scaling by the ratio between the two
    // aspects turns that letterbox into a full-bleed cover crop.
    var scale = 1 / (controller.value.aspectRatio * available.aspectRatio);
    if (scale < 1) scale = 1 / scale;

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _GlassIconButton(
              icon: Icons.close,
              onTap: () => Navigator.of(context).pop(),
            ),
            const Expanded(
              child: Text(
                'Face verification',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _prompts(Rect cutout, Size available) {
    final done = _update.phase == LivenessPhase.complete;
    final steps = _engine.steps.length;

    // Normally sits below the viewfinder, but on a short screen the oval
    // reaches far enough down to push this off the bottom — so it stops at
    // whatever leaves room for the block itself.
    const blockHeight = 190.0;
    final top = math.min(
      cutout.bottom + 34,
      math.max(cutout.top, available.height - blockHeight),
    );

    return Positioned(
      left: 0,
      right: 0,
      top: top,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Text(
                _notice ?? _update.prompt,
                key: ValueKey(_notice ?? _update.prompt),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: done ? AppColors.success : Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _notice != null
                      ? 'Follow each prompt as it appears'
                      : (_update.hint ?? ''),
                  key: ValueKey('hint:${_notice ?? _update.hint}'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < steps; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    width: i < _engine.stepIndex ? 22 : 6,
                    decoration: BoxDecoration(
                      color: i < _engine.stepIndex
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              child: const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 34,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Camera unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 14.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 30),
            AppButton(label: 'Try again', onPressed: onRetry),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
