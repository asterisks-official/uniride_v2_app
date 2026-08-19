import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../places/domain/models/saved_place.dart';
import '../../domain/models/ride_quote.dart';

/// When the trip is for.
///
/// Not a dispatch flag — nobody waits online to be assigned a trip. Both post
/// to the same marketplace and notify the other side; [instant] just means
/// "leaving now" rather than at a stated time.
enum RideMode {
  instant('INSTANT', 'Now'),
  scheduled('SCHEDULED', 'Schedule');

  const RideMode(this.wire, this.label);

  final String wire;
  final String label;
}

/// Everything the compose screen has collected so far.
///
/// A plain immutable value rather than a pile of `setState` fields, because
/// the quote depends on two of them at once and re-deriving "has anything
/// price-relevant changed?" from scattered state is how stale fares happen.
class ComposeState {
  const ComposeState({
    required this.mode,
    required this.scheduledAt,
    this.pickup,
    this.destination,
    this.genderPref = 'ANY',
    this.note = '',
  });

  final RideMode mode;

  /// Only meaningful when [mode] is [RideMode.scheduled]. Kept populated
  /// either way so switching to Schedule does not land on a blank field.
  final DateTime scheduledAt;

  final PickedPlace? pickup;
  final PickedPlace? destination;
  final String genderPref;

  /// Passenger-side only — a rider's context is their vehicle, which is
  /// already on their profile.
  final String note;

  bool get isComplete => pickup != null && destination != null;

  /// The inputs a fare depends on. Compared to decide whether to re-quote:
  /// changing the departure time must not spend a request, because distance
  /// does not depend on the hour.
  ({double? fromLat, double? fromLng, double? toLat, double? toLng})
  get fareInputs => (
    fromLat: pickup?.lat,
    fromLng: pickup?.lng,
    toLat: destination?.lat,
    toLng: destination?.lng,
  );

  ComposeState copyWith({
    RideMode? mode,
    DateTime? scheduledAt,
    PickedPlace? pickup,
    PickedPlace? destination,
    String? genderPref,
    String? note,
  }) => ComposeState(
    mode: mode ?? this.mode,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    pickup: pickup ?? this.pickup,
    destination: destination ?? this.destination,
    genderPref: genderPref ?? this.genderPref,
    note: note ?? this.note,
  );

  /// Swaps the two ends. The single most-used control on a commute screen —
  /// the trip home is the trip in, backwards.
  ComposeState get reversed => ComposeState(
    mode: mode,
    scheduledAt: scheduledAt,
    pickup: destination,
    destination: pickup,
    genderPref: genderPref,
    note: note,
  );
}

/// Fetches a price for one pair of points.
///
/// A family keyed on the pair so Riverpod caches per combination: swapping the
/// ends back and forth, or reopening the screen with the same commute, costs
/// nothing. Quoting is a server round-trip on a screen that changes on every
/// tap, so that matters.
final rideQuoteProvider = FutureProvider.autoDispose
    .family<
      RideQuote,
      ({double fromLat, double fromLng, double toLat, double toLng})
    >((ref, args) {
      return ref
          .read(ridesRepositoryProvider)
          .quote(
            fromLat: args.fromLat,
            fromLng: args.fromLng,
            toLat: args.toLat,
            toLng: args.toLng,
          );
    });
