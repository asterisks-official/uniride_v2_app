import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/error_retry.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/models/rider_profile.dart';
import '../providers/rider_notifier.dart';

class RiderVerificationScreen extends ConsumerWidget {
  const RiderVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(riderNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Become a Rider')),
      body: state.when(
        loading: () => const FormScreenSkeleton(fieldCount: 5),
        error: (e, _) => ErrorRetry(
          message: e is AppException ? e.message : 'Something went wrong',
          onRetry: () => ref.read(riderNotifierProvider.notifier).reload(),
        ),
        data: (profile) => profile == null
            ? const _RiderForm()
            : _RiderStatus(profile: profile),
      ),
    );
  }
}

// ── Status view (profile exists) ─────────────────────────────────────────────

class _RiderStatus extends ConsumerWidget {
  const _RiderStatus({required this.profile});
  final RiderProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = profile.verificationStatus;
    final isRider = ref.watch(authNotifierProvider) is Authenticated &&
        (ref.read(authNotifierProvider.notifier).currentUser?.role == 'RIDER');

    late final IconData icon;
    late final Color color;
    late final String title;
    late final String body;

    switch (status) {
      case 'APPROVED':
        icon = Icons.verified;
        color = AppColors.primary;
        title = 'You\'re a verified rider!';
        body = 'Your documents were approved. You can now post ride offers.';
      case 'REJECTED':
        icon = Icons.cancel_outlined;
        color = AppColors.error;
        title = 'Application rejected';
        body = profile.adminNote?.isNotEmpty == true
            ? 'Reason: ${profile.adminNote}'
            : 'Your documents could not be verified. Please contact support.';
      default: // PENDING
        icon = Icons.hourglass_top;
        color = AppColors.warning;
        title = 'Under review';
        body =
            'We\'re reviewing your documents. You\'ll be notified once approved.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Text(
              '${profile.vehicleMake} ${profile.vehicleModel} · ${profile.licensePlate}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            if (status == 'APPROVED' && !isRider)
              AppButton(
                label: 'Enable rider features',
                onPressed: () async {
                  await ref
                      .read(authNotifierProvider.notifier)
                      .refreshSession();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rider mode enabled')),
                    );
                  }
                },
              )
            else
              OutlinedButton(
                onPressed: () =>
                    ref.read(riderNotifierProvider.notifier).reload(),
                child: const Text('Refresh status'),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Application form (no profile yet) ────────────────────────────────────────

class _RiderForm extends ConsumerStatefulWidget {
  const _RiderForm();

  @override
  ConsumerState<_RiderForm> createState() => _RiderFormState();
}

class _RiderFormState extends ConsumerState<_RiderForm> {
  final _formKey = GlobalKey<FormState>();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  String _vehicleType = 'motorcycle';
  XFile? _license;
  XFile? _vehiclePhoto;
  XFile? _studentId;
  bool _loading = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _pick(ValueChanged<XFile> onPicked) async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (img != null) setState(() => onPicked(img));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_license == null || _vehiclePhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload your license and a vehicle photo'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(riderNotifierProvider.notifier).submit(
            vehicleType: _vehicleType,
            vehicleMake: _make.text.trim(),
            vehicleModel: _model.text.trim(),
            vehicleYear: int.parse(_year.text.trim()),
            vehicleColor: _color.text.trim(),
            licensePlate: _plate.text.trim(),
            licenseDoc: _license!,
            vehiclePhoto: _vehiclePhoto!,
            studentIdDoc: _studentId,
          );
      // On success the screen rebuilds into the status view.
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tell us about your vehicle and upload your documents. An admin '
              'will review and approve your application.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _vehicleType,
              decoration: const InputDecoration(labelText: 'Vehicle type'),
              items: const [
                DropdownMenuItem(value: 'motorcycle', child: Text('Motorcycle')),
                DropdownMenuItem(value: 'car', child: Text('Car')),
                DropdownMenuItem(value: 'cng', child: Text('CNG / Auto')),
                DropdownMenuItem(value: 'bicycle', child: Text('Bicycle')),
              ],
              onChanged: (v) => setState(() => _vehicleType = v ?? 'motorcycle'),
            ),
            const SizedBox(height: 16),
            _field(_make, 'Make (e.g. Honda)'),
            const SizedBox(height: 16),
            _field(_model, 'Model (e.g. CB Hornet)'),
            const SizedBox(height: 16),
            _field(
              _year,
              'Year',
              keyboardType: TextInputType.number,
              validator: (v) {
                final y = int.tryParse(v?.trim() ?? '');
                if (y == null || y < 2000 || y > DateTime.now().year + 1) {
                  return 'Enter a valid year';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _field(_color, 'Color'),
            const SizedBox(height: 16),
            _field(_plate, 'License plate'),
            const SizedBox(height: 24),
            _UploadTile(
              label: 'Driving license',
              file: _license,
              onTap: () => _pick((f) => _license = f),
            ),
            const SizedBox(height: 12),
            _UploadTile(
              label: 'Vehicle photo',
              file: _vehiclePhoto,
              onTap: () => _pick((f) => _vehiclePhoto = f),
            ),
            const SizedBox(height: 12),
            _UploadTile(
              label: 'Student ID (optional)',
              file: _studentId,
              onTap: () => _pick((f) => _studentId = f),
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Submit application',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: validator ??
          (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.label,
    required this.file,
    required this.onTap,
  });

  final String label;
  final XFile? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final picked = file != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.segmentTrack,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: picked ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              picked ? Icons.check_circle : Icons.upload_file,
              color: picked ? AppColors.primary : AppColors.muted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                picked ? '$label — ${file!.name}' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
