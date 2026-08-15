import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/account_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/profile_notifier.dart';

/// Collects gender and student ID from accounts created before those became
/// required at signup.
///
/// Roughly a thousand v1 accounts have neither. Enforcing the fields at login
/// would lock them out of an app they already use, so they are collected once,
/// here, and the sheet is not dismissible because gender gates female-only
/// rides — a user without it fails closed on every gender-restricted ride.
class CompleteProfileSheet extends ConsumerStatefulWidget {
  const CompleteProfileSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (_) => const CompleteProfileSheet(),
      );

  @override
  ConsumerState<CompleteProfileSheet> createState() =>
      _CompleteProfileSheetState();
}

class _CompleteProfileSheetState extends ConsumerState<CompleteProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  final _studentId = TextEditingController();
  Gender? _gender;
  bool _saving = false;

  @override
  void dispose() {
    _studentId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your gender to continue')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authNotifierProvider.notifier).completeProfile(
            gender: _gender!,
            studentIdNumber: _studentId.text.trim(),
          );
      ref.invalidate(profileNotifierProvider);
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 22,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Finish setting up your account',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'We need two more details before you can book rides. '
              'This is a one-time step.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _studentId,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                hintText: '221-15-6029',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter your student ID'
                  : null,
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Gender',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              children: [
                for (final g in Gender.values) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _gender = g),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: _gender == g
                              ? AppColors.primaryWash
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _gender == g
                                ? AppColors.primary
                                : AppColors.border,
                            width: _gender == g ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          g.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: _gender == g
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _gender == g
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (g != Gender.values.last) const SizedBox(width: 9),
                ],
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 7),
              child: Text(
                'Used to enforce female-only rides.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 24),
            AppButton(label: 'Save', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
