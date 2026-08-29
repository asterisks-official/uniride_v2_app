import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/account_enums.dart';
import '../../../../core/constants/universities.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/motion.dart';
import '../providers/auth_notifier.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/auth_tabs.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/social_login_row.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialTab = 0});

  /// 0 = Login, 1 = Register.
  final int initialTab;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Go ahead and set up\nyour account',
      subtitle: 'Sign in or sign up to start sharing rides on campus',
      showBack: false,
      child: Column(
        children: [
          AuthTabs(index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 24),
          _tab == 0 ? const _LoginForm() : const _RegisterForm(),
        ],
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _rememberMe = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // Drop the keyboard first — otherwise the HUD comes up behind it.
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(appLoadingProvider.notifier).run(
            () => ref.read(authNotifierProvider.notifier).login(
                  email: _email.text.trim(),
                  password: _password.text,
                  rememberMe: _rememberMe,
                ),
            message: 'Signing you in',
          );
    } on AppException catch (e) {
      if (mounted) showAppSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _email,
            label: 'Email Address',
            hint: 'you@diu.edu.bd',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.mail_outline,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _password,
            label: 'Password',
            hint: 'Your password',
            obscureText: true,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.lock_outline,
            onSubmitted: (_) => _submit(),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your password' : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Remember me'),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/forgot-password'),
                child: const Text('Forgot Password?'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(label: 'Login', loading: _loading, onPressed: _submit),
          const SizedBox(height: 20),
          const OrDivider(),
          const SizedBox(height: 20),
          const SocialLoginRow(),
        ],
      ),
    );
  }
}

class _RegisterForm extends ConsumerStatefulWidget {
  const _RegisterForm();

  @override
  ConsumerState<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _studentId = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  /// Null until the user picks a side. Signup is a two-step flow: choose how
  /// you're joining, then fill in the details for that side.
  JoinAs? _joinAs;
  Gender? _gender;
  String? _university;

  /// Sentinel for the "not listed yet" option — sent as empty so the backend
  /// stores nothing rather than a literal placeholder.
  static const _notListed = '__not_listed__';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _studentId.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      showAppSnack(context, 'Select your gender to continue', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final result = await ref.read(appLoadingProvider.notifier).run(
            () => ref.read(authNotifierProvider.notifier).register(
                  name: _name.text.trim(),
                  email: _email.text.trim(),
                  password: _password.text,
                  gender: _gender!,
                  studentIdNumber: _studentId.text.trim(),
                  joinAs: _joinAs ?? JoinAs.passenger,
                  university: _university == _notListed ? '' : _university,
                  phone: _phone.text.trim(),
                ),
            message: 'Creating your account',
            successMessage: 'Account created',
          );
      if (mounted) {
        context.push(
          '/otp',
          extra: {'email': _email.text.trim(), 'devOtp': result.devOtp},
        );
      }
    } on AppException catch (e) {
      if (mounted) showAppSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Step one: how are you joining? Kept separate because the two sides ask
    // for different things and mean different things — a rider is applying for
    // something an admin has to approve.
    if (_joinAs == null) return _RolePicker(onPick: _pickRole);

    final isRider = _joinAs == JoinAs.rider;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChosenRoleBar(
            joinAs: _joinAs!,
            onChange: () => setState(() => _joinAs = null),
          ),
          const SizedBox(height: 18),
          AuthTextField(
            controller: _name,
            label: 'Full Name',
            hint: 'Shakib Ahmed',
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.person_outline,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _email,
            label: 'Email Address',
            hint: 'you@diu.edu.bd',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.mail_outline,
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _studentId,
            label: 'Student ID',
            hint: '221-15-6029',
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.badge_outlined,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter your student ID'
                : null,
          ),
          const SizedBox(height: 18),
          _GenderPicker(
            value: _gender,
            onChanged: (g) => setState(() => _gender = g),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _university,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'University',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            items: [
              for (final u in kUniversities)
                DropdownMenuItem(
                  value: u.name,
                  child: Text('${u.name} (${u.shortName})'),
                ),
              const DropdownMenuItem(
                value: _notListed,
                child: Text(kOtherUniversityLabel),
              ),
            ],
            onChanged: (v) => setState(() => _university = v),
            validator: (v) =>
                v == null ? 'Select your university' : null,
          ),
          if (_university == _notListed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.segmentTrack,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "We're only live at Daffodil right now. Sign up anyway and "
                "we'll let you know the moment your campus opens.",
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          AuthTextField(
            controller: _phone,
            // Passengers need a way to reach their driver, and every in-app
            // fallback depends on the app being open.
            label: isRider ? 'Phone' : 'Phone (optional)',
            hint: '+8801712345678',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            prefixIcon: Icons.phone_outlined,
            validator: isRider
                ? (v) => (v == null || v.trim().length < 11)
                    ? 'Riders must add a phone number'
                    : null
                : null,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _password,
            label: 'Password',
            hint: 'At least 8 characters',
            obscureText: true,
            textInputAction: TextInputAction.done,
            prefixIcon: Icons.lock_outline,
            onSubmitted: (_) => _submit(),
            validator: (v) => (v == null || v.length < 8)
                ? 'Password must be at least 8 characters'
                : null,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              isRider
                  ? "We'll email you a 6-digit code. After that you'll add "
                      'your vehicle, documents and a face check — riding is '
                      'open to you once an admin approves them.'
                  : "We'll email you a 6-digit code to verify your account.",
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: isRider ? 'Continue' : 'Register',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  void _pickRole(JoinAs choice) => setState(() => _joinAs = choice);
}

// ── Step one: choose a side ──────────────────────────────────────────────────

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.onPick});

  final ValueChanged<JoinAs> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'How are you joining?',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'You can switch later — this just sets what you see first.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 20),
        _RoleCard(
          icon: Icons.person_pin_circle_outlined,
          title: 'I need a ride',
          subtitle: 'Join as a passenger',
          body: 'Browse rides students are offering and ask to join one.',
          onTap: () => onPick(JoinAs.passenger),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          icon: Icons.directions_car_outlined,
          title: 'I can drive',
          subtitle: 'Join as a rider',
          body:
              'Offer seats on trips you already make. Needs your vehicle details '
              'and documents, reviewed before you can post.',
          onTap: () => onPick(JoinAs.rider),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryWash,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ChosenRoleBar extends StatelessWidget {
  const _ChosenRoleBar({required this.joinAs, required this.onChange});

  final JoinAs joinAs;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final rider = joinAs == JoinAs.rider;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.primaryWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            rider ? Icons.directions_car_outlined : Icons.person_pin_circle_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              rider ? 'Joining as a rider' : 'Joining as a passenger',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Change', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Gender ───────────────────────────────────────────────────────────────────

class _GenderPicker extends StatelessWidget {
  const _GenderPicker({required this.value, required this.onChanged});

  final Gender? value;
  final ValueChanged<Gender> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                child: PressableScale(
                  onTap: () => onChanged(g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: value == g
                          ? AppColors.primaryWash
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: value == g
                            ? AppColors.primary
                            : AppColors.border,
                        width: value == g ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      g.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            value == g ? FontWeight.w700 : FontWeight.w500,
                        color: value == g
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
      ],
    );
  }
}
