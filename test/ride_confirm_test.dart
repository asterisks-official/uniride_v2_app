import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/features/rides/domain/models/ride.dart';

/// A ride completes only when both sides confirm. The screen can only show
/// which half is done if the model actually carries the flags — it did not,
/// which is the whole of this bug.
Map<String, dynamic> _json({
  bool riderConfirmed = false,
  bool passengerConfirmed = false,
}) {
  return {
    'id': 'ride-1',
    'type': 'OFFER',
    'mode': 'INSTANT',
    'status': 'IN_PROGRESS',
    'originAddress': 'Dhanmondi',
    'destAddress': 'DIU Ashulia',
    'scheduledAt': DateTime.now().toIso8601String(),
    'fare': '239.00',
    'seatsAvailable': 1,
    'genderPref': 'ANY',
    'riderConfirmed': riderConfirmed,
    'passengerConfirmed': passengerConfirmed,
  };
}

void main() {
  test('both confirmation flags survive parsing', () {
    final ride = Ride.fromJson(_json(riderConfirmed: true));

    expect(ride.riderConfirmed, isTrue);
    expect(ride.passengerConfirmed, isFalse);
    // Still in progress: one confirmation is not completion, and the screen
    // has to be able to tell that apart from nothing having happened.
    expect(ride.status, 'IN_PROGRESS');
  });

  test('a response without the flags defaults to unconfirmed', () {
    final bare = _json()
      ..remove('riderConfirmed')
      ..remove('passengerConfirmed');

    final ride = Ride.fromJson(bare);

    expect(ride.riderConfirmed, isFalse);
    expect(ride.passengerConfirmed, isFalse);
  });
}
