import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';

/// Rate the person you just rode with.
///
/// Reached automatically the moment both sides confirm the ride is over —
/// nobody goes looking for a rating form, and a rating asked for a day later
/// is a rating nobody gives.
///
/// Skippable, and it says so. A form that cannot be dismissed is a form people
/// answer with five stars to make it go away, which is worse than no rating at
/// all: it quietly inflates everyone.
class RateRideScreen extends ConsumerStatefulWidget {
  const RateRideScreen({super.key, required this.rideId});

  final String rideId;

  @override
  ConsumerState<RateRideScreen> createState() => _RateRideScreenState();
}

class _RateRideScreenState extends ConsumerState<RateRideScreen> {
  static const _tags = [
    'punctual',
    'friendly',
    'safe_driver',
    'clean_ride',
    'good_communication',
  ];

  int _score = 0;
  final _selected = <String>{};
  final _review = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score == 0 || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(ratingsRepositoryProvider).submit(
        rideId: widget.rideId,
        score: _score,
        review: _review.text,
        tags: _selected.toList(),
      );
      if (!mounted) return;
      showAppSnack(context, 'Thanks — your rating is in.');
      _leave();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnack(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  /// Home, not back. Back is the completed ride, and returning to a trip that
  /// is over to look at it again is nobody's next move.
  void _leave() => context.go('/home');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rate your ride'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _sending ? null : _leave,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text(
                'How was it?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Only the other person is rated, and they never see who said '
                'what.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              _Stars(
                score: _score,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _score = v);
                },
              ),
              const SizedBox(height: 28),

              // Tags only after a score. Asking what was good about a ride
              // nobody has judged yet is asking two questions at once.
              if (_score > 0) ...[
                const Text(
                  'WHAT STOOD OUT?',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _tags)
                      _TagChip(
                        label: tag.replaceAll('_', ' '),
                        selected: _selected.contains(tag),
                        onTap: () => setState(
                          () => _selected.contains(tag)
                              ? _selected.remove(tag)
                              : _selected.add(tag),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _review,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    hintText: 'Anything else? (optional)',
                  ),
                ),
                const SizedBox(height: 8),
              ],

              AppButton(
                label: 'Submit rating',
                onPressed: _score == 0 ? null : _submit,
                loading: _sending,
                loadingLabel: 'Sending',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.score, required this.onChanged});

  final int score;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => onChanged(i),
            iconSize: 40,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(),
            icon: Icon(
              i <= score ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= score ? AppColors.warning : AppColors.muted,
            ),
            tooltip: '$i star${i == 1 ? '' : 's'}',
          ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryWash : AppColors.segmentTrack,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
