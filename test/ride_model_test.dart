import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/features/rides/domain/models/ride.dart';

Map<String, dynamic> _person(String id, String name) => {
  'id': id,
  'name': name,
  'profilePictureUrl': null,
  'stats': {'averageRating': 4.6, 'ridesCompleted': 12},
};

Map<String, dynamic> _base() => {
  'id': 'r1',
  'originAddress': 'Mirpur 10',
  'destAddress': 'DIU Ashulia',
  'scheduledAt': '2026-08-20T09:00:00.000Z',
  'fare': '120.00',
  'seatsAvailable': 2,
  'status': 'SEARCHING',
  'genderPref': 'ANY',
};

void main() {
  test('an OFFER shows the driver as the poster', () {
    final ride = Ride.fromJson({
      ..._base(),
      'type': 'OFFER',
      'riderId': 'u-driver',
      'creator': _person('u-driver', 'Shakib'),
      'rider': _person('u-driver', 'Shakib'),
    });

    expect(ride.isRequest, isFalse);
    expect(ride.poster.name, 'Shakib');
    expect(ride.riderId, 'u-driver');
  });

  test('a REQUEST shows the passenger who posted it, not "Unknown"', () {
    // The exact shape the API returns for an unmatched REQUEST: no driver has
    // taken it yet, so `rider` is null and the poster is in `creator`. Reading
    // `rider` here is what rendered every passenger request in the rider feed
    // as "Unknown" with a zero rating.
    final ride = Ride.fromJson({
      ..._base(),
      'type': 'REQUEST',
      'riderId': null,
      'creator': _person('u-pax', 'Nusrat'),
      'rider': null,
    });

    expect(ride.isRequest, isTrue);
    expect(ride.poster.name, 'Nusrat');
    expect(ride.poster.averageRating, 4.6);
    expect(ride.rider, isNull, reason: 'nobody is driving it yet');
    expect(ride.riderId, isNull);
  });

  test('a matched REQUEST keeps the poster and gains a driver', () {
    final ride = Ride.fromJson({
      ..._base(),
      'type': 'REQUEST',
      'status': 'MATCHED',
      'riderId': 'u-driver',
      'creator': _person('u-pax', 'Nusrat'),
      'rider': _person('u-driver', 'Shakib'),
    });

    expect(ride.poster.name, 'Nusrat', reason: 'the poster does not change');
    expect(ride.rider?.name, 'Shakib');
  });

  test('a response with no creator falls back to the driver', () {
    // v1 compatibility: older payloads predate `creator`. Falling back beats
    // showing "Unknown" for a ride that plainly has a driver.
    final ride = Ride.fromJson({
      ..._base(),
      'riderId': 'u-driver',
      'rider': _person('u-driver', 'Shakib'),
    });

    expect(ride.type, 'OFFER', reason: 'the safe default for old payloads');
    expect(ride.poster.name, 'Shakib');
  });

  test('a response with neither degrades instead of throwing', () {
    final ride = Ride.fromJson({..._base(), 'riderId': null});

    expect(ride.poster.name, 'Unknown');
    expect(ride.rider, isNull);
  });
}
