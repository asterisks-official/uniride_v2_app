class RiderSummary {
  const RiderSummary({
    required this.id,
    required this.name,
    this.profilePictureUrl,
    required this.averageRating,
    required this.ridesCompleted,
  });

  final String id;
  final String name;
  final String? profilePictureUrl;
  final double averageRating;
  final int ridesCompleted;

  factory RiderSummary.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>?;
    return RiderSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      profilePictureUrl: json['profilePictureUrl'] as String?,
      averageRating: (stats?['averageRating'] as num?)?.toDouble() ?? 0.0,
      ridesCompleted: (stats?['ridesCompleted'] as num?)?.toInt() ?? 0,
    );
  }
}

class PassengerSummary {
  const PassengerSummary({
    required this.id,
    required this.name,
    this.profilePictureUrl,
  });

  final String id;
  final String name;
  final String? profilePictureUrl;

  factory PassengerSummary.fromJson(Map<String, dynamic> json) =>
      PassengerSummary(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown',
        profilePictureUrl: json['profilePictureUrl'] as String?,
      );
}

class Ride {
  const Ride({
    required this.id,
    required this.riderId,
    required this.rider,
    required this.originAddress,
    required this.destAddress,
    required this.scheduledAt,
    required this.fare,
    required this.seatsAvailable,
    required this.status,
    required this.genderPref,
    this.passenger,
    this.pendingRequestCount,
  });

  final String id;
  final String riderId;
  final RiderSummary rider;
  final String originAddress;
  final String destAddress;
  final DateTime scheduledAt;
  final double fare;
  final int seatsAvailable;
  final String status;
  final String genderPref;

  // Only present in the detail view response.
  final PassengerSummary? passenger;
  final int? pendingRequestCount;

  factory Ride.fromJson(Map<String, dynamic> json) {
    final riderJson = json['rider'] as Map<String, dynamic>?;
    final passengerJson = json['passenger'] as Map<String, dynamic>?;
    final count = json['_count'] as Map<String, dynamic>?;

    // Prisma Decimal serialises as a string e.g. "150.00".
    final fareRaw = json['fare'];
    final fare = fareRaw is num
        ? fareRaw.toDouble()
        : double.tryParse(fareRaw?.toString() ?? '0') ?? 0.0;

    return Ride(
      id: json['id'] as String,
      riderId: json['riderId'] as String? ?? '',
      rider: riderJson != null
          ? RiderSummary.fromJson(riderJson)
          : const RiderSummary(
              id: '',
              name: 'Unknown',
              averageRating: 0,
              ridesCompleted: 0,
            ),
      originAddress: json['originAddress'] as String? ?? '',
      destAddress: json['destAddress'] as String? ?? '',
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      fare: fare,
      seatsAvailable: (json['seatsAvailable'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'SEARCHING',
      genderPref: json['genderPref'] as String? ?? 'ANY',
      passenger:
          passengerJson != null ? PassengerSummary.fromJson(passengerJson) : null,
      pendingRequestCount: (count?['requests'] as num?)?.toInt(),
    );
  }
}
