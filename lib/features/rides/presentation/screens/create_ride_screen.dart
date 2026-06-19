import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/my_rides_notifier.dart';
import '../providers/rides_feed_notifier.dart';

const double _kWheelH = 180.0;
const double _kItemH = 52.0;
const List<int> _kMinSteps = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class CreateRideFormScreen extends ConsumerStatefulWidget {
  const CreateRideFormScreen({super.key, required this.type});

  /// 'OFFER' = driving, 'REQUEST' = passenger
  final String type;

  @override
  ConsumerState<CreateRideFormScreen> createState() =>
      _CreateRideFormScreenState();
}

class _CreateRideFormScreenState extends ConsumerState<CreateRideFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _fareCtrl = TextEditingController();
  final _originFocus = FocusNode();
  final _destFocus = FocusNode();

  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);

  bool _submitting = false;
  String? _error;

  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  bool get _isOffer => widget.type == 'OFFER';

  @override
  void initState() {
    super.initState();
    _originFocus.addListener(() => setState(() {}));
    _destFocus.addListener(() => setState(() {}));
    _fareCtrl.addListener(() => setState(() {}));
    _entry.forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    _originCtrl.dispose();
    _destCtrl.dispose();
    _fareCtrl.dispose();
    _originFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  DateTime get _scheduledAt => DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute,
      );

  Future<void> _pickDate() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CalendarSheet(
        initialDate: _date,
        onConfirm: (d) {
          HapticFeedback.lightImpact();
          setState(() => _date = d);
        },
      ),
    );
  }

  Future<void> _pickTime() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimePickerSheet(
        initialTime: _time,
        onConfirm: (t) {
          HapticFeedback.lightImpact();
          setState(() => _time = t);
        },
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final scheduledAt = _scheduledAt;
    if (scheduledAt
        .isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      setState(() => _error = 'Schedule at least 30 minutes from now.');
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
            seatsAvailable: 1,
            genderPref: 'ANY',
            type: widget.type,
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
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final bodyFade =
        CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    final bodySlide = Tween<Offset>(
            begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _FormHeader(isOffer: _isOffer),
          Expanded(
            child: FadeTransition(
              opacity: bodyFade,
              child: SlideTransition(
                position: bodySlide,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TripCard(
                          isOffer: _isOffer,
                          originCtrl: _originCtrl,
                          destCtrl: _destCtrl,
                          originFocus: _originFocus,
                          destFocus: _destFocus,
                          date: _date,
                          time: _time,
                          onDateTap: _pickDate,
                          onTimeTap: _pickTime,
                        ),

                        const SizedBox(height: 16),

                        _DetailsCard(
                          isOffer: _isOffer,
                          fareCtrl: _fareCtrl,
                          onFareQuickPick: (v) {
                            HapticFeedback.lightImpact();
                            setState(() => _fareCtrl.text = v);
                          },
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _ErrorBanner(message: _error!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SlideToSubmit(
        isOffer: _isOffer,
        submitting: _submitting,
        onSubmit: _submit,
        bottomPad: bottomPad,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form header
// ─────────────────────────────────────────────────────────────────────────────

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.isOffer});
  final bool isOffer;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final accentColor =
        isOffer ? AppColors.primary : const Color(0xFF60A5FA);
    final label = isOffer ? 'Driving' : 'Passenger';

    return Container(
      color: AppColors.lightBackground,
      padding: EdgeInsets.fromLTRB(20, topPad + 10, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.lightBorder),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.lightTextPrimary, size: 15),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: accentColor.withValues(alpha: 0.25), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOffer
                          ? Icons.directions_bike_rounded
                          : Icons.hail_rounded,
                      color: accentColor,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                isOffer ? 'Offer Ride' : 'Request Ride',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip card (route + schedule combined)
// ─────────────────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.isOffer,
    required this.originCtrl,
    required this.destCtrl,
    required this.originFocus,
    required this.destFocus,
    required this.date,
    required this.time,
    required this.onDateTap,
    required this.onTimeTap,
  });

  final bool isOffer;
  final TextEditingController originCtrl;
  final TextEditingController destCtrl;
  final FocusNode originFocus;
  final FocusNode destFocus;
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _LocationRow(
            controller: originCtrl,
            focusNode: originFocus,
            nextFocus: destFocus,
            hint: isOffer ? 'Pickup location' : 'Where you are',
            example: 'e.g. DIU Campus Gate',
            isOrigin: true,
            isFocused: originFocus.hasFocus,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              children: [
                _DashedLine(),
                const Expanded(
                    child: Divider(height: 1, color: AppColors.lightBorder)),
              ],
            ),
          ),
          _LocationRow(
            controller: destCtrl,
            focusNode: destFocus,
            hint: isOffer ? 'Drop-off location' : 'Where you\'re going',
            example: 'e.g. Mirpur 10, Dhaka',
            isOrigin: false,
            isFocused: destFocus.hasFocus,
            textInputAction: TextInputAction.done,
          ),
          const Divider(height: 1, indent: 20, endIndent: 20, color: AppColors.lightBorder),
          _ScheduleRow(
            icon: Icons.calendar_month_rounded,
            label: 'DATE',
            value: DateFormat('EEE, MMM d').format(date),
            onTap: onDateTap,
          ),
          const Divider(height: 1, indent: 62, color: AppColors.lightBorder),
          _ScheduleRow(
            icon: Icons.access_time_rounded,
            label: 'TIME',
            value: time.format(context),
            onTap: onTimeTap,
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.example,
    required this.isOrigin,
    required this.isFocused,
    this.nextFocus,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final String hint;
  final String example;
  final bool isOrigin;
  final bool isFocused;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    final dotColor = isOrigin ? AppColors.primary : AppColors.error;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isFocused
            ? dotColor.withValues(alpha: 0.04)
            : Colors.transparent,
        borderRadius: isOrigin
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isFocused ? 14 : 11,
            height: isFocused ? 14 : 11,
            decoration: BoxDecoration(
              color: isOrigin ? dotColor : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: dotColor,
                width: isOrigin ? 0 : 2,
              ),
            ),
            child: isOrigin
                ? null
                : isFocused
                    ? Center(
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              textInputAction: textInputAction,
              onFieldSubmitted: (_) {
                if (nextFocus != null) {
                  FocusScope.of(context).requestFocus(nextFocus);
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 15,
                  color: AppColors.lightMuted,
                  fontWeight: FontWeight.w400,
                ),
                helperText: example,
                helperStyle:
                    const TextStyle(fontSize: 11, color: AppColors.lightMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller.clear();
                FocusScope.of(context).requestFocus(focusNode);
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded,
                    size: 16, color: AppColors.lightMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          width: 1.5,
          height: 5,
          color: AppColors.lightBorder,
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.lightMuted,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.lightTextPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.lightBorder),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.lightMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarSheet extends StatefulWidget {
  const _CalendarSheet({required this.initialDate, required this.onConfirm});
  final DateTime initialDate;
  final ValueChanged<DateTime> onConfirm;

  @override
  State<_CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<_CalendarSheet> {
  late DateTime _selected;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _month = DateTime(_selected.year, _selected.month);
  }

  bool _isPast(int day) {
    final date = DateTime(_month.year, _month.month, day);
    final today = DateTime.now();
    return date.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool _isSelected(int day) =>
      _selected.year == _month.year &&
      _selected.month == _month.month &&
      _selected.day == day;

  bool _isToday(int day) {
    final now = DateTime.now();
    return now.year == _month.year &&
        now.month == _month.month &&
        now.day == day;
  }

  void _prevMonth() {
    final prev = DateTime(_month.year, _month.month - 1);
    final now = DateTime.now();
    if (!prev.isBefore(DateTime(now.year, now.month))) {
      setState(() => _month = prev);
    }
  }

  void _nextMonth() =>
      setState(() => _month = DateTime(_month.year, _month.month + 1));

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday - 1;
    final now = DateTime.now();
    final isAtCurrentMonth =
        _month.year == now.year && _month.month == now.month;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),

          // Month navigation
          Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: isAtCurrentMonth ? null : _prevMonth,
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: _nextMonth,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Day-of-week headers
          Row(
            children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.lightMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),

          const SizedBox(height: 6),

          // Date grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < firstWeekday) return const SizedBox.shrink();
              final day = index - firstWeekday + 1;
              final isPast = _isPast(day);
              final isSelected = _isSelected(day);
              final isToday = _isToday(day);

              return GestureDetector(
                onTap: isPast
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() => _selected =
                            DateTime(_month.year, _month.month, day));
                      },
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isToday && !isSelected
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? Colors.white
                              : isPast
                                  ? AppColors.lightMuted.withValues(alpha: 0.35)
                                  : isToday
                                      ? AppColors.primary
                                      : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(_selected);
                Navigator.pop(context);
              },
              child: Text(
                'Confirm · ${DateFormat('EEE, MMMM d').format(_selected)}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppColors.lightBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? AppColors.lightBorder : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.lightTextPrimary : AppColors.lightBorder,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time picker bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet(
      {required this.initialTime, required this.onConfirm});
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onConfirm;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _hour; // 1–12
  late int _minIdx;
  late bool _isAm;

  late final FixedExtentScrollController _hCtrl;
  late final FixedExtentScrollController _mCtrl;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTime;
    _isAm = t.period == DayPeriod.am;
    _hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final nearest = (t.minute ~/ 5) * 5;
    _minIdx = _kMinSteps.indexOf(nearest);
    if (_minIdx < 0) _minIdx = 0;
    _hCtrl = FixedExtentScrollController(initialItem: _hour - 1);
    _mCtrl = FixedExtentScrollController(initialItem: _minIdx);
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _mCtrl.dispose();
    super.dispose();
  }

  TimeOfDay get _result {
    int h = _hour;
    if (_isAm) {
      if (h == 12) h = 0;
    } else {
      if (h != 12) h += 12;
    }
    return TimeOfDay(hour: h, minute: _kMinSteps[_minIdx]);
  }

  String get _label {
    final m = _kMinSteps[_minIdx].toString().padLeft(2, '0');
    return '$_hour:$m ${_isAm ? "AM" : "PM"}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const selTop = (_kWheelH - _kItemH) / 2;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPad + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Departure Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.lightTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.lightMuted,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            height: _kWheelH,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Selection highlight band
                Positioned(
                  top: selTop,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: _kItemH,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WheelPicker(
                      controller: _hCtrl,
                      items: List.generate(12, (i) => '${i + 1}'),
                      onChanged: (i) {
                        HapticFeedback.selectionClick();
                        setState(() => _hour = i + 1);
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text(
                        ' : ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    _WheelPicker(
                      controller: _mCtrl,
                      items: _kMinSteps
                          .map((m) => m.toString().padLeft(2, '0'))
                          .toList(),
                      onChanged: (i) {
                        HapticFeedback.selectionClick();
                        setState(() => _minIdx = i);
                      },
                    ),
                    const SizedBox(width: 20),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PeriodButton(
                          label: 'AM',
                          selected: _isAm,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isAm = true);
                          },
                        ),
                        const SizedBox(height: 8),
                        _PeriodButton(
                          label: 'PM',
                          selected: !_isAm,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isAm = false);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onConfirm(_result);
                Navigator.pop(context);
              },
              child: Text('Confirm · $_label'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPicker extends StatelessWidget {
  const _WheelPicker({
    required this.controller,
    required this.items,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final List<String> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: _kWheelH,
      child: ListWheelScrollView(
        controller: controller,
        itemExtent: _kItemH,
        perspective: 0.004,
        diameterRatio: 1.8,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        children: items
            .map(
              (label) => Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 54,
        height: 38,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.lightSegmentTrack,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.lightBorder,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Details card (fare)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.isOffer,
    required this.fareCtrl,
    required this.onFareQuickPick,
  });

  final bool isOffer;
  final TextEditingController fareCtrl;
  final ValueChanged<String> onFareQuickPick;

  static const _fareQuickPicks = ['30', '50', '80', '100', '120', '150'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlineLabel(isOffer ? 'Ride Fare' : 'Your Budget'),
          const SizedBox(height: 10),
          _FareInput(isOffer: isOffer, controller: fareCtrl),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _fareQuickPicks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final v = _fareQuickPicks[i];
                final selected = fareCtrl.text == v;
                return GestureDetector(
                  onTap: () => onFareQuickPick(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.lightSegmentTrack,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Text(
                      '৳$v',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLabel extends StatelessWidget {
  const _InlineLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
      );
}

class _FareInput extends StatelessWidget {
  const _FareInput({required this.isOffer, required this.controller});
  final bool isOffer;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSegmentTrack,
        border: Border.all(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFFEEF4EE),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(13),
                bottomLeft: Radius.circular(13),
              ),
            ),
            child: const Center(
              child: Text(
                '৳',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.lightTextPrimary,
                letterSpacing: -1,
              ),
              decoration: const InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.lightMuted,
                  letterSpacing: -1,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                isDense: true,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter an amount';
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slide to submit
// ─────────────────────────────────────────────────────────────────────────────

class _SlideToSubmit extends StatefulWidget {
  const _SlideToSubmit({
    required this.isOffer,
    required this.submitting,
    required this.onSubmit,
    required this.bottomPad,
  });
  final bool isOffer;
  final bool submitting;
  final VoidCallback onSubmit;
  final double bottomPad;

  @override
  State<_SlideToSubmit> createState() => _SlideToSubmitState();
}

class _SlideToSubmitState extends State<_SlideToSubmit>
    with TickerProviderStateMixin {
  static const _thumbSize = 54.0;
  static const _trackH = 62.0;
  static const _hPad = 4.0;

  double _dx = 0;
  double _maxDx = 0;
  bool _triggered = false;

  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && !_triggered && !widget.submitting) {
        _hint.forward().then((_) {
          if (mounted) _hint.reverse();
        });
      }
    });
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails _) {
    if (widget.submitting) return;
    _triggered = false;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (widget.submitting || _triggered) return;
    setState(() => _dx = (_dx + d.delta.dx).clamp(0.0, _maxDx));
  }

  void _onEnd(DragEndDetails _) {
    if (widget.submitting || _triggered) return;
    if (_dx >= _maxDx * 0.85) {
      setState(() {
        _triggered = true;
        _dx = _maxDx;
      });
      HapticFeedback.heavyImpact();
      widget.onSubmit();
    } else {
      HapticFeedback.lightImpact();
      setState(() => _dx = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isOffer ? 'Slide to post offer' : 'Slide to post request';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, (widget.bottomPad < 16 ? 16 : widget.bottomPad) + 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _maxDx = constraints.maxWidth - _thumbSize - _hPad * 2;
          final progress = _maxDx > 0 ? (_dx / _maxDx) : 0.0;

          return Container(
            height: _trackH,
            decoration: BoxDecoration(
              color: widget.submitting
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(_trackH / 2),
            ),
            clipBehavior: Clip.none,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Filled progress
                if (!widget.submitting)
                  AnimatedContainer(
                    duration: _triggered
                        ? const Duration(milliseconds: 200)
                        : Duration.zero,
                    width: _dx + _thumbSize + _hPad * 2,
                    height: _trackH,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(_trackH / 2),
                    ),
                  ),

                // Label
                if (!widget.submitting)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: progress > 0.5
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppColors.primary.withValues(alpha: 0.7),
                          letterSpacing: -0.2,
                        ),
                        child: Text(label),
                      ),
                    ),
                  ),

                // Submitting state
                if (widget.submitting)
                  const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Creating...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Thumb
                if (!widget.submitting)
                  AnimatedBuilder(
                    animation: _hint,
                    builder: (context, child) {
                      final hintOffset = _hint.value * (_maxDx * 0.25);
                      final totalDx = _dx + hintOffset;
                      return AnimatedPositioned(
                        duration: _triggered || _dx == 0
                            ? const Duration(milliseconds: 300)
                            : Duration.zero,
                        curve: Curves.easeOutCubic,
                        left: _hPad + totalDx,
                        top: (_trackH - _thumbSize) / 2,
                        child: child!,
                      );
                    },
                    child: GestureDetector(
                      onHorizontalDragStart: _onStart,
                      onHorizontalDragUpdate: _onUpdate,
                      onHorizontalDragEnd: _onEnd,
                      child: Container(
                        width: _thumbSize,
                        height: _thumbSize,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _triggered
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: AppColors.error.withValues(alpha: 0.20)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style:
                    const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ],
        ),
      );
}
