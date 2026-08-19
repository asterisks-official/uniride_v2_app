import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../../../core/constants/account_enums.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/providers/gender_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/motion.dart';
import '../../../places/domain/models/saved_place.dart';
import '../../../places/presentation/providers/saved_places_notifier.dart';
import '../../../places/presentation/screens/location_picker_screen.dart';
import '../../../profile/presentation/providers/profile_notifier.dart';
import '../../domain/models/ride_quote.dart';
import '../providers/compose_ride_notifier.dart';
import '../providers/my_rides_notifier.dart';
import '../providers/rides_feed_notifier.dart';
import '../widgets/compose_widgets.dart';
import '../widgets/trip_map.dart';
import '../widgets/trip_sheet_widgets.dart';

/// Post a trip — ask for one, or offer one.
///
/// Map-first: the route fills the top of the screen and everything else sits
/// in a sheet beneath it. The map is not decoration here. The fare is computed
/// from distance, so the trip has to be *visible* for the price to mean
/// anything — "৳285" says very little on its own and a great deal next to the
/// road it was measured along.
///
/// Which side you post is your role, not a control on this screen: a rider
/// offers, a passenger asks. A rider who needs a lift switches to passenger
/// mode on their profile, and this screen follows.
class CreateRideScreen extends ConsumerStatefulWidget {
  const CreateRideScreen({super.key});

  @override
  ConsumerState<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends ConsumerState<CreateRideScreen> {
  late ComposeState _state = ComposeState(
    mode: RideMode.instant,
    scheduledAt: _defaultTime(),
  );

  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  bool _seeded = false;

  /// A scheduled trip needs to be far enough out that someone can still take
  /// it. Does not apply to Now, which is the whole point of Now.
  static const _scheduleLead = Duration(minutes: 30);

  /// Dhaka, for the map before either end is chosen.
  static const _dhaka = LatLng(23.7806, 90.4074);

  static DateTime _defaultTime() {
    final soon = DateTime.now().add(_scheduleLead);
    // People schedule at :00 and :30, not at :17.
    final minutes = soon.minute <= 30 ? 30 : 60;
    return DateTime(
      soon.year,
      soon.month,
      soon.day,
      soon.hour,
    ).add(Duration(minutes: minutes));
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Pre-fills the pickup from the most recently used saved place.
  ///
  /// Takes the [AsyncValue] rather than its contents: a list that has not
  /// loaded is indistinguishable from an empty one once unwrapped, and that
  /// difference decides whether the picker is thrown open in the user's face.
  void _seedFrom(AsyncValue<List<SavedPlace>> placesAsync) {
    if (_seeded) return;
    final places = placesAsync.asData?.value;
    if (places == null) return; // still loading — decide nothing

    _seeded = true;
    if (places.isEmpty || _state.pickup != null) return;

    final place = PickedPlace.fromSaved(places.first);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _state = _state.copyWith(pickup: place));
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pick({required bool isPickup}) async {
    final current = isPickup ? _state.pickup : _state.destination;
    final picked = await LocationPickerScreen.open(
      context,
      title: isPickup ? 'Where are you now?' : 'Where are you going?',
      // Opens on the point already chosen, so adjusting is a nudge rather
      // than starting from the middle of Dhaka again.
      initial: current == null ? null : LatLng(current.lat, current.lng),
      // The pickup asks where you are, so it goes there itself. The
      // destination is somewhere you are not, and centring it on the user
      // would only be a point to drag away from.
      locateOnOpen: isPickup,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _state = isPickup
          ? _state.copyWith(pickup: picked)
          : _state.copyWith(destination: picked);
    });
  }

  /// Now, or a chosen time. One sheet rather than a segmented control plus a
  /// row of chips — picking "now" is one tap and picking a time is two.
  Future<void> _pickWhen() async {
    final chosen = await showModalBottomSheet<DateTime?>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _WhenSheet(current: _state.scheduledAt),
    );
    if (chosen == null || !mounted) return;

    setState(() {
      // The sentinel: epoch zero means "now" rather than a time.
      _state = chosen.millisecondsSinceEpoch == 0
          ? _state.copyWith(mode: RideMode.instant)
          : _state.copyWith(mode: RideMode.scheduled, scheduledAt: chosen);
    });
  }

  Future<void> _submit({
    required bool isOffer,
    required RideQuote? quote,
  }) async {
    final pickup = _state.pickup;
    final destination = _state.destination;
    if (pickup == null || destination == null || quote == null) return;

    final scheduled = _state.mode == RideMode.scheduled;
    if (scheduled &&
        _state.scheduledAt.isBefore(DateTime.now().add(_scheduleLead))) {
      showAppSnack(
        context,
        'Pick a time at least 30 minutes from now.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final rideId = await ref
          .read(ridesRepositoryProvider)
          .createTrip(
            type: isOffer ? 'OFFER' : 'REQUEST',
            mode: _state.mode.wire,
            pickup: pickup,
            destination: destination,
            scheduledAt: scheduled
                ? _state.scheduledAt.toUtc().toIso8601String()
                : null,
            genderPref: _state.genderPref,
          );

      if (!mounted) return;
      ref.invalidate(myRidesProvider);
      ref.invalidate(ridesFeedProvider);
      ref.invalidate(savedPlacesProvider);
      // The waiting screen, not the detail view: the post has no other side
      // yet, and replacing the route keeps back from re-posting the form.
      context.pushReplacement('/rides/$rideId/waiting');
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        showAppSnack(context, e.message, isError: true);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileNotifierProvider).asData?.value;
    final gender = ref.watch(cachedGenderProvider) ?? profile?.gender;

    // Requires the capability *and* the mode; the server enforces the pair.
    final isOffer =
        profile?.isRider == true && profile?.activeMode == ActiveMode.rider;
    final scheduled = _state.mode == RideMode.scheduled;

    _seedFrom(ref.watch(savedPlacesProvider));

    final accent = isOffer ? AppColors.primary : _passengerAccent;
    final f = _state.fareInputs;
    final quoteAsync = _state.isComplete
        ? ref.watch(
            rideQuoteProvider((
              fromLat: f.fromLat!,
              fromLng: f.fromLng!,
              toLat: f.toLat!,
              toLng: f.toLng!,
            )),
          )
        : null;
    final quote = quoteAsync?.asData?.value;

    return Scaffold(
      backgroundColor: AppColors.background,
      // A plain bar rather than controls floating over the map. The map is
      // showing one thing — the route — and a pill sitting on top of it
      // competes with the only content it has.
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(isOffer ? 'Offer a ride' : 'Get a ride'),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 42,
            child: TripMap(
              origin: _state.pickup == null
                  ? _dhaka
                  : LatLng(_state.pickup!.lat, _state.pickup!.lng),
              destination: _state.destination == null
                  ? _dhaka
                  : LatLng(_state.destination!.lat, _state.destination!.lng),
              route: [
                for (final (lat, lng)
                    in quote?.polyline ?? const <(double, double)>[])
                  LatLng(lat, lng),
              ],
              // Extra at the bottom: the sheet's rounded top overlaps the map,
              // and a pin tucked under it cannot be seen.
              padding: const EdgeInsets.fromLTRB(36, 30, 36, 46),
            ),
          ),

          Expanded(
            flex: 58,
            child: _TripSheet(
              accent: accent,
              isOffer: isOffer,
              scheduled: scheduled,
              state: _state,
              quote: quote,
              quoteFailed: quoteAsync?.hasError ?? false,
              gender: gender,
              noteController: _noteCtrl,
              submitting: _submitting,
              whenLabel: scheduled
                  ? DateFormat('E h:mm a').format(_state.scheduledAt)
                  : 'Now',
              onFrom: () => _pick(isPickup: true),
              onTo: () => _pick(isPickup: false),
              onSwap: _state.isComplete
                  ? () => setState(() => _state = _state.reversed)
                  : null,
              onWhen: _pickWhen,
              onGenderPref: (g) =>
                  setState(() => _state = _state.copyWith(genderPref: g)),
              onRetryQuote: () => ref.invalidate(rideQuoteProvider),
              onSubmit: () => _submit(isOffer: isOffer, quote: quote),
            ),
          ),
        ],
      ),
    );
  }

  /// Passenger side gets its own accent so the two are never mistaken for each
  /// other at a glance. An identity, not a status.
  static const _passengerAccent = Color(0xFF3B5BDB);
}

// ── Sheet ────────────────────────────────────────────────────────────────────

class _TripSheet extends StatelessWidget {
  const _TripSheet({
    required this.accent,
    required this.isOffer,
    required this.scheduled,
    required this.state,
    required this.quote,
    required this.quoteFailed,
    required this.gender,
    required this.noteController,
    required this.submitting,
    required this.whenLabel,
    required this.onFrom,
    required this.onTo,
    required this.onSwap,
    required this.onWhen,
    required this.onGenderPref,
    required this.onRetryQuote,
    required this.onSubmit,
  });

  final Color accent;
  final bool isOffer;
  final bool scheduled;
  final ComposeState state;
  final RideQuote? quote;
  final bool quoteFailed;
  final Gender? gender;
  final TextEditingController noteController;
  final bool submitting;
  final String whenLabel;

  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback? onSwap;
  final VoidCallback onWhen;
  final ValueChanged<String> onGenderPref;
  final VoidCallback onRetryQuote;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // The title yields first: a chosen date is information,
                      // a static heading is not.
                      Flexible(
                        child: Text(
                          isOffer ? 'Ride details' : 'Trip details',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: TripWhenButton(
                          label: whenLabel,
                          scheduled: scheduled,
                          onTap: onWhen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  FadeSlideIn(
                    child: TripEndpointRows(
                      from: state.pickup?.displayName,
                      to: state.destination?.displayName,
                      onFrom: onFrom,
                      onTo: onTo,
                      onSwap: onSwap,
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (quoteFailed)
                    _QuoteFailed(onRetry: onRetryQuote)
                  else if (state.isComplete)
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 60),
                      child: TripFareCard(
                        quote: quote,
                        isOffer: isOffer,
                        accent: accent,
                      ),
                    )
                  else
                    const _NeedsBothEnds(),

                  if (state.isComplete && !quoteFailed) ...[
                    const SizedBox(height: 10),
                    _WhatHappensNote(isOffer: isOffer, scheduled: scheduled),
                  ],

                  // Shown to women only. The restriction exists for their
                  // safety, and a men-only ride is not something anyone has
                  // asked for.
                  if (gender == Gender.female) ...[
                    const SizedBox(height: 18),
                    ComposeLabel(
                      isOffer ? 'Who can ride with me' : "Who I'll ride with",
                    ),
                    ComposeSegmented<String>(
                      accent: accent,
                      value: state.genderPref,
                      options: const [
                        ('ANY', 'Anyone', null),
                        ('FEMALE_ONLY', 'Women only', Icons.shield_outlined),
                      ],
                      onChanged: onGenderPref,
                    ),
                  ],

                  if (!isOffer) ...[
                    const SizedBox(height: 18),
                    const ComposeLabel('Anything they should know'),
                    ComposeCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: noteController,
                        maxLength: 120,
                        maxLines: 2,
                        minLines: 1,
                        style: const TextStyle(
                          fontSize: 14.5,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: "Optional — \"I'll have a backpack\"",
                          hintStyle: TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                          ),
                          counterText: '',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AppButton(
                label: _submitLabel(),
                icon: scheduled
                    ? Icons.event_available_rounded
                    : Icons.bolt_rounded,
                loading: submitting,
                loadingLabel: 'Posting',
                // Committing without a resolved price would mean posting at a
                // fare nobody has seen.
                onPressed: quote == null ? null : onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _submitLabel() {
    if (isOffer) return scheduled ? 'Post this ride' : 'Offer this ride now';
    return scheduled ? 'Post my request' : 'Find me a rider';
  }
}

/// One line on what pressing the button will actually do.
///
/// Worth the space because the four combinations differ in a way the button
/// label cannot carry: notifying every rider nearby and posting an advert for
/// later are not the same act, and nobody should discover which one they chose
/// after the fact.
class _WhatHappensNote extends StatelessWidget {
  const _WhatHappensNote({required this.isOffer, required this.scheduled});

  final bool isOffer;
  final bool scheduled;

  @override
  Widget build(BuildContext context) {
    final text = switch ((isOffer, scheduled)) {
      (true, false) =>
        'Passengers nearby get notified right away. You choose who joins.',
      (true, true) => 'Posted for passengers to find. You choose who joins.',
      (false, false) =>
        'Every rider nearby gets notified. The first to accept takes it.',
      (false, true) =>
        "Posted for riders heading your way. You'll be notified when one "
            'takes it.',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 4),
        Icon(
          scheduled ? Icons.campaign_outlined : Icons.bolt_rounded,
          size: 15,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _NeedsBothEnds extends StatelessWidget {
  const _NeedsBothEnds();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      children: [
        Icon(Icons.route_outlined, size: 20, color: AppColors.muted),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Set both ends to see the route and the fare.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}

class _QuoteFailed extends StatelessWidget {
  const _QuoteFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, size: 20, color: AppColors.error),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            "Couldn't price this trip",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

// ── When sheet ───────────────────────────────────────────────────────────────

/// Now, or a time. Returns epoch zero for "now" and a real [DateTime]
/// otherwise; null if dismissed.
class _WhenSheet extends StatelessWidget {
  const _WhenSheet({required this.current});

  final DateTime current;

  /// The hours a campus commute actually happens at.
  static const _hours = [7, 8, 9, 14, 16, 18];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final slots = <DateTime>[];
    for (final hour in _hours) {
      var slot = DateTime(now.year, now.month, now.day, hour);
      // A slot already gone today is tomorrow's slot, not a dead option.
      if (slot.isBefore(now.add(const Duration(minutes: 30)))) {
        slot = slot.add(const Duration(days: 1));
      }
      slots.add(slot);
    }
    slots.sort();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'When are you leaving?',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _WhenOption(
              icon: Icons.bolt_rounded,
              title: 'Now',
              subtitle: 'Everyone nearby is notified straight away',
              onTap: () => Navigator.of(
                context,
              ).pop(DateTime.fromMillisecondsSinceEpoch(0)),
            ),
            const Divider(height: 20, color: AppColors.border),
            const ComposeLabel('Later today or tomorrow'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in slots.take(4))
                  ComposeChip(
                    label: _chipLabel(slot, now),
                    selected: slot == current,
                    onTap: () => Navigator.of(context).pop(slot),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Pick an exact time',
              variant: AppButtonVariant.outline,
              icon: Icons.calendar_today_outlined,
              onPressed: () async {
                final picked = await _pickExact(context, current);
                if (picked != null && context.mounted) {
                  Navigator.of(context).pop(picked);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<DateTime?> _pickExact(
    BuildContext context,
    DateTime initial,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static String _chipLabel(DateTime slot, DateTime now) {
    final time = DateFormat('h:mm a').format(slot);
    return slot.day != now.day ? '$time tmrw' : time;
  }
}

class _WhenOption extends StatelessWidget {
  const _WhenOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PressableScale(
    scale: 0.99,
    onTap: onTap,
    child: Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
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
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.muted,
        ),
      ],
    ),
  );
}
