import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../providers/my_rides_notifier.dart';
import '../providers/rides_feed_notifier.dart';

class CreateRideScreen extends ConsumerStatefulWidget {
  const CreateRideScreen({super.key});

  @override
  ConsumerState<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends ConsumerState<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();

  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _fareCtrl = TextEditingController();

  late String _type; // 'OFFER' | 'REQUEST' — set in initState based on role
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  int _seats = 1;
  String _genderPref = 'ANY';

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authNotifierProvider);
    final isRider = auth is Authenticated && auth.user.role == 'RIDER';
    _type = isRider ? 'OFFER' : 'REQUEST';
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    _fareCtrl.dispose();
    super.dispose();
  }

  DateTime get _scheduledAt => DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final scheduledAt = _scheduledAt;
    if (scheduledAt.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      setState(
        () => _error = 'Schedule at least 30 minutes from now.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final rideId = await ref.read(ridesRepositoryProvider).createRide(
            originAddress: _originCtrl.text.trim(),
            destAddress: _destCtrl.text.trim(),
            fare: double.parse(_fareCtrl.text.trim()),
            scheduledAt: scheduledAt.toUtc().toIso8601String(),
            seatsAvailable: _seats,
            genderPref: _genderPref,
            type: _type,
          );

      if (!mounted) return;
      ref.invalidate(myRidesProvider);
      ref.invalidate(ridesFeedProvider);
      context.pushReplacement('/rides/$rideId');
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffer = _type == 'OFFER';

    return Scaffold(
      appBar: AppBar(
        title: Text(isOffer ? 'Offer a Ride' : 'Request a Ride'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Type toggle ───────────────────────────────────────────────────
            _TypeToggle(
              value: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 24),

            // ── Route ─────────────────────────────────────────────────────────
            _SectionHeader(label: 'Route'),
            const SizedBox(height: 10),
            _AddressField(
              controller: _originCtrl,
              label: isOffer ? 'Pickup location' : 'Where you are',
              hint: 'e.g. DIU Campus Gate, Ashulia',
            ),
            const SizedBox(height: 12),
            _AddressField(
              controller: _destCtrl,
              label: isOffer ? 'Drop-off location' : 'Where you\'re going',
              hint: 'e.g. Mirpur 10, Dhaka',
            ),
            const SizedBox(height: 24),

            // ── Schedule ──────────────────────────────────────────────────────
            _SectionHeader(label: 'Schedule'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat('EEE, MMM d').format(_date),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.schedule_outlined,
                    label: _time.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Details ───────────────────────────────────────────────────────
            _SectionHeader(
              label: isOffer ? 'Ride Details' : 'Trip Details',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _fareCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: isOffer ? 'Fare per seat' : 'Budget',
                prefixText: '৳ ',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter an amount';
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            Text(
              isOffer ? 'Available seats' : 'Seats needed',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(4, (i) {
                final n = i + 1;
                final selected = _seats == n;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _seats = n),
                    child: Container(
                      width: 52,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.segmentTrack,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              selected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$n',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            Text(
              'Gender preference',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final opt in [
                  ('ANY', 'Anyone'),
                  ('FEMALE_ONLY', 'Female only'),
                  ('MALE_ONLY', 'Male only'),
                ])
                  GestureDetector(
                    onTap: () => setState(() => _genderPref = opt.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _genderPref == opt.$1
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.segmentTrack,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _genderPref == opt.$1
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        opt.$2,
                        style: TextStyle(
                          fontSize: 13,
                          color: _genderPref == opt.$1
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: _genderPref == opt.$1
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SkeletonBox(width: 80, height: 16, borderRadius: 8)
                  : Text(isOffer ? 'Post Ride Offer' : 'Post Ride Request'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Type toggle ───────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.segmentTrack,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _TypeOption(
            label: 'Offer a Ride',
            icon: Icons.directions_car_outlined,
            description: "I'm driving",
            selected: value == 'OFFER',
            onTap: () => onChanged('OFFER'),
          ),
          _TypeOption(
            label: 'Request a Ride',
            icon: Icons.hail_outlined,
            description: 'I need a ride',
            selected: value == 'REQUEST',
            onTap: () => onChanged('REQUEST'),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.icon,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AppColors.primary : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      );
}

class _AddressField extends StatelessWidget {
  const _AddressField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'This field is required' : null,
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
