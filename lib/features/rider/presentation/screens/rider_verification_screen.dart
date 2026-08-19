import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/motion.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/models/rider_profile.dart';
import '../providers/rider_notifier.dart';
import '../widgets/rider_form_widgets.dart';
import '../widgets/rider_unlocked_celebration.dart';
import 'face_verification_screen.dart';

class RiderVerificationScreen extends ConsumerStatefulWidget {
  const RiderVerificationScreen({super.key});

  @override
  ConsumerState<RiderVerificationScreen> createState() =>
      _RiderVerificationScreenState();
}

class _RiderVerificationScreenState
    extends ConsumerState<RiderVerificationScreen> {
  /// The applicant has opened a rejected application to correct it. Reset by
  /// the resubmission itself, which flips the profile back to PENDING.
  bool _correcting = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(riderNotifierProvider);
    final auth = ref.watch(authNotifierProvider);
    // Locked means this account signed up as a rider and has no approved
    // application: there is nowhere else in the app for them to be, so the
    // screen drops its exits rather than offering a door that goes nowhere.
    final locked = auth is Authenticated && auth.riderGate == RiderGate.locked;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: state.when(
        loading: () => const SafeArea(
          child: Column(
            children: [
              SizedBox(height: 56),
              Expanded(child: FormScreenSkeleton(fieldCount: 4)),
            ],
          ),
        ),
        error: (e, _) => SafeArea(
          child: Column(
            children: [
              RiderStepHeader(
                step: 0,
                total: 0,
                onBack: locked ? null : () => leaveRiderFlow(context),
              ),
              Expanded(
                child: ErrorRetry(
                  message: e is AppException
                      ? e.message
                      : 'Something went wrong',
                  onRetry: () =>
                      ref.read(riderNotifierProvider.notifier).reload(),
                ),
              ),
            ],
          ),
        ),
        data: (profile) {
          if (profile == null) return _ApplicationFlow(locked: locked);
          if (_correcting && profile.isRejected) {
            return _ApplicationFlow(
              locked: locked,
              existing: profile,
              onCancel: () => setState(() => _correcting = false),
            );
          }
          return _RiderStatus(
            profile: profile,
            locked: locked,
            onCorrect: () => setState(() => _correcting = true),
          );
        },
      ),
    );
  }
}

void leaveRiderFlow(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

// ── Application wizard ───────────────────────────────────────────────────────

/// The four steps after the intro. Splitting the application up is what makes
/// it survivable: one long scroll asking for a vehicle, four documents and a
/// face scan reads as a wall, and people close it.
enum _Step { intro, vehicle, documents, face, review }

class _ApplicationFlow extends ConsumerStatefulWidget {
  const _ApplicationFlow({required this.locked, this.existing, this.onCancel});

  /// True when the applicant cannot leave until this is submitted.
  final bool locked;

  /// Set when correcting a rejected application: the form starts filled in and
  /// submits as an edit rather than a new application.
  final RiderProfile? existing;

  /// Backs out of a correction, returning to the rejection notice.
  final VoidCallback? onCancel;

  @override
  ConsumerState<_ApplicationFlow> createState() => _ApplicationFlowState();
}

class _ApplicationFlowState extends ConsumerState<_ApplicationFlow> {
  /// Only motorcycles are being onboarded for now. The rest are listed but
  /// unselectable — a lone option with no explanation reads as a broken form,
  /// and flipping `available` is all it takes to open one up.
  static const _vehicleTypes =
      <({String value, String label, IconData icon, bool available})>[
        (
          value: 'motorcycle',
          label: 'Motorcycle',
          icon: Icons.two_wheeler,
          available: true,
        ),
        (
          value: 'car',
          label: 'Car',
          icon: Icons.directions_car_outlined,
          available: false,
        ),
        (
          value: 'cng',
          label: 'CNG / Auto',
          icon: Icons.local_taxi_outlined,
          available: false,
        ),
        (
          value: 'bicycle',
          label: 'Bicycle',
          icon: Icons.pedal_bike_outlined,
          available: false,
        ),
      ];

  final _pageController = PageController();
  final _vehicleFormKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();

  _Step _step = _Step.intro;
  String _vehicleType = 'motorcycle';
  XFile? _license;
  XFile? _vehiclePhoto;
  XFile? _platePhoto;
  XFile? _studentId;
  XFile? _selfie;
  bool _submitting = false;

  /// True when correcting a rejected application rather than making a new one.
  bool get _correcting => widget.existing != null;

  /// A slot counts as filled if a new file was picked *or* one is already on
  /// file from the rejected submission.
  bool _filled(XFile? picked, String? existingUrl) =>
      picked != null || existingUrl != null;

  bool get _documentsComplete =>
      _filled(_license, widget.existing?.licenseDocUrl) &&
      _filled(_vehiclePhoto, widget.existing?.vehiclePhotoUrl) &&
      _filled(_platePhoto, widget.existing?.licensePlatePhotoUrl) &&
      _filled(_studentId, widget.existing?.studentIdDocUrl);

  bool get _faceComplete => _filled(_selfie, widget.existing?.selfieUrl);

  int get _documentsCount => [
    _filled(_license, widget.existing?.licenseDocUrl),
    _filled(_vehiclePhoto, widget.existing?.vehiclePhotoUrl),
    _filled(_platePhoto, widget.existing?.licensePlatePhotoUrl),
    _filled(_studentId, widget.existing?.studentIdDocUrl),
  ].where((filled) => filled).length;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) return;
    // Prefilled so a rejection over one blurry photo does not cost the
    // applicant the whole form again.
    _vehicleType = existing.vehicleType;
    _make.text = existing.vehicleMake;
    _model.text = existing.vehicleModel;
    _year.text = '${existing.vehicleYear}';
    _color.text = existing.vehicleColor;
    _plate.text = existing.licensePlate;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goTo(_Step step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pageController.animateToPage(
      step.index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Null on the intro step of a locked new application — there is no back to
  /// go. A correction can always be abandoned back to the rejection notice.
  VoidCallback? get _backAction {
    if (_step != _Step.intro) return _back;
    if (widget.onCancel != null) return widget.onCancel;
    return widget.locked ? null : () => leaveRiderFlow(context);
  }

  void _back() {
    if (_step != _Step.intro) {
      _goTo(_Step.values[_step.index - 1]);
      return;
    }
    _backAction?.call();
  }

  void _advance() {
    switch (_step) {
      case _Step.intro:
        _goTo(_Step.vehicle);
      case _Step.vehicle:
        if (_vehicleFormKey.currentState?.validate() ?? false) {
          _goTo(_Step.documents);
        }
      case _Step.documents:
        if (!_documentsComplete) {
          showAppSnack(
            context,
            'Add all four documents to continue',
            isError: true,
          );
          return;
        }
        _goTo(_Step.face);
      case _Step.face:
        if (!_faceComplete) {
          _startFaceCheck();
        } else {
          _goTo(_Step.review);
        }
      case _Step.review:
        _submit();
    }
  }

  String get _ctaLabel => switch (_step) {
    _Step.intro => _correcting ? 'Correct my details' : 'Get started',
    _Step.face => _faceComplete ? 'Continue' : 'Start face check',
    _Step.review => _correcting ? 'Resubmit application' : 'Submit application',
    _ => 'Continue',
  };

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickDocument({
    required String title,
    required XFile? current,
    required ValueChanged<XFile?> onPicked,
  }) async {
    final source = await askImageSource(
      context,
      title: title,
      canRemove: current != null,
      onRemove: () => setState(() => onPicked(null)),
    );
    if (source == null) return;
    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image != null && mounted) setState(() => onPicked(image));
    } on PlatformException catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          e.message ?? 'That image could not be opened.',
          isError: true,
        );
      }
    }
  }

  Future<void> _startFaceCheck() async {
    final shot = await FaceVerificationScreen.open(context);
    if (shot == null || !mounted) return;
    setState(() => _selfie = shot);
    showAppSnack(context, 'Face verified');
  }

  Future<void> _submit() async {
    if (!_documentsComplete || !_faceComplete) return;
    setState(() => _submitting = true);
    final loading = ref.read(appLoadingProvider.notifier);
    try {
      await loading.run(
        () => _correcting
            ? ref
                  .read(riderNotifierProvider.notifier)
                  .resubmit(
                    vehicleType: _vehicleType,
                    vehicleMake: _make.text.trim(),
                    vehicleModel: _model.text.trim(),
                    vehicleYear: int.parse(_year.text.trim()),
                    vehicleColor: _color.text.trim(),
                    licensePlate: _plate.text.trim(),
                    licenseDoc: _license,
                    vehiclePhoto: _vehiclePhoto,
                    licensePlatePhoto: _platePhoto,
                    studentIdDoc: _studentId,
                    selfie: _selfie,
                    onStage: loading.report,
                  )
            : ref
                  .read(riderNotifierProvider.notifier)
                  .submit(
                    vehicleType: _vehicleType,
                    vehicleMake: _make.text.trim(),
                    vehicleModel: _model.text.trim(),
                    vehicleYear: int.parse(_year.text.trim()),
                    vehicleColor: _color.text.trim(),
                    licensePlate: _plate.text.trim(),
                    licenseDoc: _license!,
                    vehiclePhoto: _vehiclePhoto!,
                    licensePlatePhoto: _platePhoto!,
                    studentIdDoc: _studentId!,
                    selfie: _selfie!,
                    onStage: loading.report,
                  ),
        message: 'Preparing your application',
        successMessage: _correcting
            ? 'Sent back for review'
            : 'Application submitted',
      );
      // Success rebuilds this screen into the status view — the notifier now
      // holds a PENDING profile.
    } on AppException catch (e) {
      if (mounted) showAppSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Handled manually: system back should walk the wizard backwards, and on
      // the first step of a locked application it should do nothing at all.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _backAction?.call();
      },
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: RiderStepHeader(
              step: _step == _Step.intro ? 0 : _step.index,
              total: _Step.values.length - 1,
              onBack: _backAction,
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _introStep(),
                _vehicleStep(),
                _documentsStep(),
                _faceStep(),
                _reviewStep(),
              ],
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _page({required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Staggered so the step's sections arrive in reading order instead
          // of the whole page appearing at once.
          for (var i = 0; i < children.length; i++)
            FadeSlideIn(
              delay: Duration(milliseconds: 45 * i),
              child: children[i],
            ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Row(
            children: [
              if (_step != _Step.intro) ...[
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'Back',
                    variant: AppButtonVariant.outline,
                    onPressed: _submitting ? null : _back,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 3,
                child: AppButton(
                  label: _ctaLabel,
                  icon: _step == _Step.face && !_faceComplete
                      ? Icons.face_retouching_natural
                      : null,
                  loading: _submitting,
                  onPressed: _advance,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 0: intro ──────────────────────────────────────────────────────────

  Widget _introStep() {
    final existing = widget.existing;
    if (existing != null) return _correctionIntro(existing);

    return _page(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Rider application',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Fill the empty seats\non trips you already make',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.22,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _heroFact(Icons.schedule, 'About 5 minutes'),
                  const SizedBox(width: 18),
                  _heroFact(Icons.verified_outlined, 'Reviewed in 24h'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const RiderPageTitle(
          title: 'What you’ll need',
          subtitle:
              'Have these ready before you start — the application is easier '
              'to finish in one go.',
        ),
        const SizedBox(height: 18),
        const RiderSection(
          padded: true,
          children: [
            RiderBulletRow(
              icon: Icons.directions_car_outlined,
              title: 'Your vehicle details',
              body: 'Make, model, year, colour and number plate.',
            ),
            RiderBulletRow(
              icon: Icons.badge_outlined,
              title: 'Driving licence and student ID',
              body: 'Clear photos — every corner readable.',
            ),
            RiderBulletRow(
              icon: Icons.photo_camera_outlined,
              title: 'Photos of the vehicle and plate',
              body: 'Taken in daylight, the whole vehicle in frame.',
            ),
            RiderBulletRow(
              icon: Icons.face_retouching_natural,
              title: 'A live face check',
              body: 'A few seconds on camera to confirm it is really you.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryWash,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.locked
                      ? 'You signed up as a rider, so UniRide opens up once '
                            'this application is approved. It usually takes '
                            'under 24 hours.'
                      : 'Keep using UniRide as a passenger while your '
                            'application is reviewed.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Intro for a rejected application: what the reviewer said, what it costs
  /// to get it wrong again, then the same form prefilled.
  Widget _correctionIntro(RiderProfile existing) {
    return _page(
      children: [
        const RiderPageTitle(
          title: 'Fix and resubmit',
          subtitle:
              'Your details are already filled in below — change what '
              'the reviewer flagged and send it back.',
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.report_problem_outlined,
                    size: 17,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Why it was rejected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                existing.adminNote?.isNotEmpty == true
                    ? existing.adminNote!
                    : 'No reason was given. Check that every document is '
                          'sharp, uncropped and in date.',
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AttemptsNotice(profile: existing),
        const SizedBox(height: 22),
        const RiderSection(
          children: [
            RiderBulletRow(
              icon: Icons.edit_outlined,
              title: 'Change only what you need to',
              body:
                  'Documents you already sent stay attached unless you '
                  'replace them.',
            ),
            RiderBulletRow(
              icon: Icons.schedule,
              title: 'Back in the queue',
              body:
                  'Resubmitting returns your application to review — usually '
                  'decided within 24 hours.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroFact(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Step 1: vehicle ────────────────────────────────────────────────────────

  Widget _vehicleStep() {
    return Form(
      key: _vehicleFormKey,
      child: _page(
        children: [
          const RiderPageTitle(
            title: 'Your vehicle',
            subtitle: 'This is what passengers see before they ask to join.',
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 9),
            child: Text(
              'Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // A fixed row height rather than an aspect ratio: the tile's
            // content has a natural height, and deriving it from the screen
            // width is what made it overflow on narrow phones.
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 92,
            ),
            children: [
              for (final type in _vehicleTypes)
                VehicleTypeTile(
                  icon: type.icon,
                  label: type.label,
                  enabled: type.available,
                  selected: _vehicleType == type.value,
                  onTap: () => setState(() => _vehicleType = type.value),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'We’re onboarding motorcycles first. Cars and CNGs open up once '
              'the routes around campus are busy enough to need them.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 24),
          RiderSection(
            title: 'Details',
            footnote:
                'The plate is checked against the photo you upload next, so '
                'enter it exactly as it appears.',
            children: [
              RiderFieldRow(
                controller: _make,
                label: 'Make',
                hint: 'Honda',
                maxLength: 50,
              ),
              RiderFieldRow(
                controller: _model,
                label: 'Model',
                hint: 'CB Hornet 160R',
                maxLength: 100,
              ),
              RiderFieldRow(
                controller: _year,
                label: 'Year',
                hint: '2022',
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: (v) {
                  final year = int.tryParse(v?.trim() ?? '');
                  if (year == null ||
                      year < 2000 ||
                      year > DateTime.now().year + 1) {
                    return 'Enter a year between 2000 and '
                        '${DateTime.now().year + 1}';
                  }
                  return null;
                },
              ),
              RiderFieldRow(
                controller: _color,
                label: 'Colour',
                hint: 'Red',
                maxLength: 30,
              ),
              RiderFieldRow(
                controller: _plate,
                label: 'Plate',
                hint: 'DHA-1234',
                textCapitalization: TextCapitalization.characters,
                maxLength: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 2: documents ──────────────────────────────────────────────────────

  Widget _documentsStep() {
    final existing = widget.existing;
    return _page(
      children: [
        SwapIn(
          value: '$_documentsCount/$_documentsComplete',
          child: RiderPageTitle(
            title: 'Documents',
            subtitle: _documentsComplete
                ? _correcting
                      ? 'All four on file. Replace any the reviewer flagged.'
                      : 'All four added. You can still change any of them.'
                : '$_documentsCount of 4 added. Photos only — make sure the '
                      'text is readable.',
          ),
        ),
        const SizedBox(height: 22),
        RiderSection(
          padded: false,
          children: [
            DocumentUploadTile(
              label: 'Driving licence',
              description: 'Front side, all four corners visible',
              icon: Icons.credit_card_outlined,
              file: _license,
              onFile: existing?.licenseDocUrl != null,
              onTap: () => _pickDocument(
                title: 'Driving licence',
                current: _license,
                onPicked: (f) => _license = f,
              ),
            ),
            DocumentUploadTile(
              label: 'Student ID',
              description: 'Proves you study here',
              icon: Icons.badge_outlined,
              file: _studentId,
              onFile: existing?.studentIdDocUrl != null,
              onTap: () => _pickDocument(
                title: 'Student ID',
                current: _studentId,
                onPicked: (f) => _studentId = f,
              ),
            ),
            DocumentUploadTile(
              label: 'Vehicle photo',
              description: 'The whole vehicle, in daylight',
              icon: Icons.directions_car_outlined,
              file: _vehiclePhoto,
              onFile: existing?.vehiclePhotoUrl != null,
              onTap: () => _pickDocument(
                title: 'Vehicle photo',
                current: _vehiclePhoto,
                onPicked: (f) => _vehiclePhoto = f,
              ),
            ),
            DocumentUploadTile(
              label: 'Number plate',
              description: 'Close enough to read every character',
              icon: Icons.pin_outlined,
              file: _platePhoto,
              onFile: existing?.licensePlatePhotoUrl != null,
              onTap: () => _pickDocument(
                title: 'Number plate photo',
                current: _platePhoto,
                onPicked: (f) => _platePhoto = f,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _PrivacyNote(
          'Documents are visible only to the UniRide review team. Passengers '
          'never see them.',
        ),
      ],
    );
  }

  // ── Step 3: face check ─────────────────────────────────────────────────────

  Widget _faceStep() {
    // A capture from this session shows the photo back; one carried over from
    // a rejected submission is only reported as done, since it lives on the
    // server rather than on the device.
    final captured = _selfie != null;
    final done = _faceComplete;
    return _page(
      children: [
        RiderPageTitle(
          title: done ? 'Face verified' : 'Face check',
          subtitle: captured
              ? 'Captured live and matched to this application.'
              : done
              ? 'The check you passed earlier still stands. Redo it if the '
                    'reviewer asked you to.'
              : 'A few seconds on camera confirms a real person is behind '
                    'these documents.',
        ),
        const SizedBox(height: 26),
        Center(
          child: SizedBox(
            height: 196,
            width: 172,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.primaryWash
                        : AppColors.segmentTrack,
                    borderRadius: BorderRadius.circular(96),
                    border: Border.all(
                      color: done ? AppColors.success : AppColors.border,
                      width: done ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: captured
                      ? Image.file(
                          File(_selfie!.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person_outline,
                            size: 64,
                            color: AppColors.muted,
                          ),
                        )
                      : Icon(
                          done
                              ? Icons.verified_user_outlined
                              : Icons.face_retouching_natural,
                          size: 68,
                          color: done ? AppColors.success : AppColors.muted,
                        ),
                ),
                if (done)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (done) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _startFaceCheck,
              child: Text(captured ? 'Retake face check' : 'Redo face check'),
            ),
          ),
        ],
        const SizedBox(height: 22),
        const RiderSection(
          children: [
            RiderBulletRow(
              icon: Icons.camera_front_outlined,
              title: 'Captured live',
              body:
                  'You’ll be asked to blink, smile and turn your head, in a '
                  'random order. A photo held up to the camera cannot do that.',
            ),
            RiderBulletRow(
              icon: Icons.fact_check_outlined,
              title: 'Matched to your documents',
              body:
                  'Our reviewers compare it with your licence and student ID.',
            ),
            RiderBulletRow(
              icon: Icons.lock_outline,
              title: 'Never shown to passengers',
              body: 'It is stored with your application and nowhere else.',
            ),
          ],
        ),
      ],
    );
  }

  // ── Step 4: review ─────────────────────────────────────────────────────────

  Widget _reviewStep() {
    final type = _vehicleTypes.firstWhere(
      (t) => t.value == _vehicleType,
      orElse: () => _vehicleTypes.first,
    );
    final existing = widget.existing;

    String docValue(XFile? picked, String? existingUrl) => picked != null
        ? 'Replaced'
        : existingUrl != null
        ? 'On file'
        : 'Missing';

    return _page(
      children: [
        RiderPageTitle(
          title: _correcting ? 'Review & resubmit' : 'Review & submit',
          subtitle: _correcting
              ? 'This goes straight back into the review queue.'
              : 'Check everything below, then send it to our review team.',
        ),
        const SizedBox(height: 22),
        if (existing != null) ...[
          _AttemptsNotice(profile: existing),
          const SizedBox(height: 20),
        ],
        RiderSection(
          title: 'Vehicle',
          action: _EditButton(onTap: () => _goTo(_Step.vehicle)),
          children: [
            RiderReviewRow(label: 'Type', value: type.label),
            RiderReviewRow(
              label: 'Vehicle',
              value: '${_make.text.trim()} ${_model.text.trim()}',
            ),
            RiderReviewRow(label: 'Year', value: _year.text.trim()),
            RiderReviewRow(label: 'Colour', value: _color.text.trim()),
            RiderReviewRow(label: 'Plate', value: _plate.text.trim()),
          ],
        ),
        const SizedBox(height: 20),
        RiderSection(
          title: 'Documents',
          action: _EditButton(onTap: () => _goTo(_Step.documents)),
          children: [
            RiderReviewRow(
              label: 'Driving licence',
              value: docValue(_license, existing?.licenseDocUrl),
              done: _filled(_license, existing?.licenseDocUrl),
            ),
            RiderReviewRow(
              label: 'Student ID',
              value: docValue(_studentId, existing?.studentIdDocUrl),
              done: _filled(_studentId, existing?.studentIdDocUrl),
            ),
            RiderReviewRow(
              label: 'Vehicle photo',
              value: docValue(_vehiclePhoto, existing?.vehiclePhotoUrl),
              done: _filled(_vehiclePhoto, existing?.vehiclePhotoUrl),
            ),
            RiderReviewRow(
              label: 'Number plate',
              value: docValue(_platePhoto, existing?.licensePlatePhotoUrl),
              done: _filled(_platePhoto, existing?.licensePlatePhotoUrl),
            ),
          ],
        ),
        const SizedBox(height: 20),
        RiderSection(
          title: 'Identity',
          action: _EditButton(onTap: () => _goTo(_Step.face)),
          children: [
            RiderReviewRow(
              label: 'Face check',
              value: _selfie != null
                  ? 'Verified'
                  : _faceComplete
                  ? 'Verified earlier'
                  : 'Not done',
              done: _faceComplete,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _PrivacyNote(
          _correcting
              ? 'Resubmitting confirms these details are genuine. Applications '
                    'rejected ${AppConstants.maxRiderRejections} times are '
                    'blocked for good.'
              : 'By submitting you confirm the vehicle is yours to drive and '
                    'that these documents are genuine. Riding with false '
                    'documents gets the account removed.',
        ),
      ],
    );
  }
}

/// How many resubmissions are left, and what running out costs.
///
/// Stated plainly and repeatedly because the consequence is permanent: an
/// applicant on their last attempt should not discover the limit by hitting it.
class _AttemptsNotice extends StatelessWidget {
  const _AttemptsNotice({required this.profile});

  final RiderProfile profile;

  @override
  Widget build(BuildContext context) {
    final left = profile.attemptsLeft;
    final lastChance = left <= 1;
    final tint = lastChance ? AppColors.error : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            lastChance ? Icons.gpp_maybe_outlined : Icons.info_outline,
            size: 18,
            color: tint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              lastChance
                  ? 'This is your last attempt. If it is rejected again, the '
                        'account is blocked and you will not be able to sign '
                        'up with these details again.'
                  : '$left of ${AppConstants.maxRiderRejections} attempts '
                        'left. After ${AppConstants.maxRiderRejections} '
                        'rejected applications the account is blocked.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: lastChance ? FontWeight.w600 : FontWeight.w400,
                color: lastChance ? tint : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Edit',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline, size: 15, color: AppColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Status view (a profile already exists) ───────────────────────────────────

class _RiderStatus extends ConsumerStatefulWidget {
  const _RiderStatus({
    required this.profile,
    required this.locked,
    required this.onCorrect,
  });

  final RiderProfile profile;

  /// True while the application is unapproved — the rest of the app is closed
  /// to them until it is.
  final bool locked;

  /// Opens the rejected application for correction.
  final VoidCallback onCorrect;

  @override
  ConsumerState<_RiderStatus> createState() => _RiderStatusState();
}

class _RiderStatusState extends ConsumerState<_RiderStatus> {
  bool _enabling = false;

  /// Turns an approval into actual access, then makes a moment of it.
  ///
  /// The refresh is what grants the RIDER role to this session — until it
  /// lands nothing has changed, so the celebration waits on it rather than
  /// playing over a request that can still fail. And it only plays if the role
  /// actually came back granted: a server that approved the documents without
  /// promoting the account is a state worth reporting, not congratulating.
  Future<void> _enableRider() async {
    setState(() => _enabling = true);
    try {
      await ref.read(authNotifierProvider.notifier).refreshSession();
    } on AppException catch (e) {
      if (mounted) showAppSnack(context, e.message, isError: true);
      return;
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
    if (!mounted) return;

    final granted =
        ref.read(authNotifierProvider.notifier).currentUser?.role == 'RIDER';
    if (!granted) {
      showAppSnack(
        context,
        'Rider access hasn’t come through yet. Try again in a moment.',
        isError: true,
      );
      return;
    }

    final leave = await RiderUnlockedCelebration.open(context);
    if (leave == true && mounted) leaveRiderFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final locked = widget.locked;
    final onCorrect = widget.onCorrect;

    final status = profile.verificationStatus;
    final approved = status == 'APPROVED';
    // Out of attempts: the account is blocked server-side, and the session
    // still in memory is the only reason this screen is reachable at all.
    final blocked = profile.isRejected && profile.attemptsLeft == 0;
    final rejected = profile.isRejected && !blocked;
    final isRider =
        ref.read(authNotifierProvider.notifier).currentUser?.role == 'RIDER';

    final (
      IconData icon,
      Color color,
      String title,
      String body,
    ) = switch (status) {
      'APPROVED' => (
        Icons.verified_rounded,
        AppColors.success,
        'You’re a verified rider',
        'Your documents were approved. You can post ride offers now.',
      ),
      'REJECTED' when blocked => (
        Icons.block,
        AppColors.error,
        'Account blocked',
        'This application was rejected '
            '${AppConstants.maxRiderRejections} times, so the account has been '
            'blocked. Contact support if you believe this is a mistake.',
      ),
      'REJECTED' => (
        Icons.error_outline_rounded,
        AppColors.error,
        'Not approved yet',
        profile.adminNote?.isNotEmpty == true
            ? 'Reviewer’s note: ${profile.adminNote}'
            : 'Your documents could not be verified. Check that each one is '
                  'sharp, uncropped and in date, then send it back.',
      ),
      _ => (
        Icons.hourglass_top_rounded,
        AppColors.warning,
        'Under review',
        'Most applications are decided within 24 hours. We’ll notify you the '
            'moment there’s an answer — UniRide opens up as soon as you’re '
            'approved.',
      ),
    };

    return PopScope(
      canPop: !locked,
      child: SafeArea(
        child: Column(
          children: [
            RiderStepHeader(
              step: 0,
              total: 0,
              onBack: locked ? null : () => leaveRiderFlow(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  children: [
                    Container(
                      height: 96,
                      width: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(alpha: 0.12),
                      ),
                      child: Icon(icon, size: 46, color: color),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (rejected) ...[
                      _AttemptsNotice(profile: profile),
                      const SizedBox(height: 28),
                    ] else if (!blocked) ...[
                      _Timeline(approved: approved),
                      const SizedBox(height: 28),
                    ],
                    RiderSection(
                      title: 'Your vehicle',
                      children: [
                        RiderReviewRow(
                          label: 'Vehicle',
                          value:
                              '${profile.vehicleMake} ${profile.vehicleModel}',
                        ),
                        RiderReviewRow(
                          label: 'Year',
                          value: '${profile.vehicleYear}',
                        ),
                        RiderReviewRow(
                          label: 'Colour',
                          value: profile.vehicleColor,
                        ),
                        RiderReviewRow(
                          label: 'Plate',
                          value: profile.licensePlate,
                        ),
                        if (profile.faceVerifiedAt != null)
                          const RiderReviewRow(
                            label: 'Face check',
                            value: 'Verified',
                            done: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (blocked)
                      AppButton(
                        label: 'Sign out',
                        variant: AppButtonVariant.outline,
                        onPressed: () =>
                            ref.read(authNotifierProvider.notifier).logout(),
                      )
                    else if (rejected)
                      AppButton(
                        label: 'Fix and resubmit',
                        icon: Icons.edit_outlined,
                        onPressed: onCorrect,
                      )
                    else if (approved && !isRider)
                      AppButton(
                        label: 'Enable rider features',
                        icon: Icons.two_wheeler_rounded,
                        loading: _enabling,
                        loadingLabel: 'Switching you over',
                        onPressed: _enableRider,
                      )
                    else
                      AppButton(
                        label: 'Check for an update',
                        variant: AppButtonVariant.outline,
                        onPressed: () async {
                          await ref
                              .read(riderNotifierProvider.notifier)
                              .reload();
                          // The gate is what actually lets them out, and it is
                          // held on the session rather than on this screen.
                          await ref
                              .read(authNotifierProvider.notifier)
                              .recheckRiderGate();
                        },
                      ),
                    if (locked && !blocked) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'You’ll be able to browse and book rides once your '
                        'application is approved.',
                        key: ValueKey('locked-note'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Submitted → Under review → Approved. Waiting is easier when you can see
/// where in the queue you are.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.approved});

  final bool approved;

  @override
  Widget build(BuildContext context) {
    const labels = ['Submitted', 'Under review', 'Approved'];
    final reached = approved ? 3 : 2;

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Column(
            children: [
              Container(
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < reached
                      ? AppColors.primary
                      : AppColors.segmentTrack,
                ),
                child: Icon(
                  i < reached ? Icons.check : Icons.circle,
                  size: i < reached ? 13 : 7,
                  color: i < reached ? Colors.white : AppColors.muted,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: i < reached ? FontWeight.w600 : FontWeight.w500,
                  color: i < reached ? AppColors.textPrimary : AppColors.muted,
                ),
              ),
            ],
          ),
          if (i != labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 26),
                color: i + 1 < reached
                    ? AppColors.primary
                    : AppColors.segmentTrack,
              ),
            ),
        ],
      ],
    );
  }
}
