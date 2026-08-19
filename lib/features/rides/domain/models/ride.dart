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
    required this.type,
    this.mode = 'SCHEDULED',
    required this.riderId,
    required this.creator,
    required this.rider,
    required this.originAddress,
    required this.destAddress,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    required this.scheduledAt,
    DateTime? createdAt,
    required this.fare,
    required this.seatsAvailable,
    required this.status,
    required this.genderPref,
    this.passenger,
    this.pendingRequestCount,
  }) : _createdAt = createdAt;

  final String id;

  /// 'OFFER' (driver offering) or 'REQUEST' (passenger needing a ride).
  final String type;

  /// 'INSTANT' (leaving now) or 'SCHEDULED' (for a stated time).
  final String mode;

  /// The actual driver. Null for unmatched REQUEST posts (filled at match).
  final String? riderId;

  /// Whoever posted the ride. For OFFER this is the driver; for REQUEST the passenger.
  final RiderSummary creator;
  final RiderSummary? rider;
  final String originAddress;
  final String destAddress;

  /// The two ends as coordinates. Nullable because rides posted by v1 clients
  /// were stored at (0,0) — see the ride-creation plan's F1 — so a ride can
  /// exist with an address and no usable point.
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;

  /// Whether the ride can be drawn on a map at all.
  bool get hasRoute =>
      originLat != null &&
      originLng != null &&
      destLat != null &&
      destLng != null &&
      !(originLat == 0 && originLng == 0) &&
      !(destLat == 0 && destLng == 0);
  final DateTime scheduledAt;

  /// When the post was made. Falls back to [scheduledAt], which for an
  /// INSTANT ride is the same instant — the server stamps it at creation.
  final DateTime? _createdAt;
  DateTime get createdAt => _createdAt ?? scheduledAt;

  final double fare;
  final int seatsAvailable;
  final String status;
  final String genderPref;

  // Only present in the detail view response.
  final PassengerSummary? passenger;
  final int? pendingRequestCount;

  bool get isRequest => type == 'REQUEST';
  bool get isInstant => mode == 'INSTANT';

  /// The person to display on cards/headers — the poster.
  RiderSummary get poster => creator;

  factory Ride.fromJson(Map<String, dynamic> json) {
    final riderJson = json['rider'] as Map<String, dynamic>?;
    final creatorJson = json['creator'] as Map<String, dynamic>?;
    final passengerJson = json['passenger'] as Map<String, dynamic>?;
    final count = json['_count'] as Map<String, dynamic>?;

    // Prisma Decimal serialises as a string e.g. "150.00".
    final fareRaw = json['fare'];
    final fare = fareRaw is num
        ? fareRaw.toDouble()
        : double.tryParse(fareRaw?.toString() ?? '0') ?? 0.0;

    final rider = riderJson != null ? RiderSummary.fromJson(riderJson) : null;
    // Older responses may omit `creator`; fall back to rider, then Unknown.
    final creator = creatorJson != null
        ? RiderSummary.fromJson(creatorJson)
        : rider ??
              const RiderSummary(
                id: '',
                name: 'Unknown',
                averageRating: 0,
                ridesCompleted: 0,
              );

    return Ride(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'OFFER',
      mode: json['mode'] as String? ?? 'SCHEDULED',
      riderId: json['riderId'] as String?,
      creator: creator,
      rider: rider,
      originAddress: json['originAddress'] as String? ?? '',
      destAddress: json['destAddress'] as String? ?? '',
      originLat: (json['originLat'] as num?)?.toDouble(),
      originLng: (json['originLng'] as num?)?.toDouble(),
      destLat: (json['destLat'] as num?)?.toDouble(),
      destLng: (json['destLng'] as num?)?.toDouble(),
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      createdAt: switch (json['createdAt']) {
        final String raw => DateTime.tryParse(raw),
        _ => null,
      },
      fare: fare,
      seatsAvailable: (json['seatsAvailable'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'SEARCHING',
      genderPref: json['genderPref'] as String? ?? 'ANY',
      passenger: passengerJson != null
          ? PassengerSummary.fromJson(passengerJson)
          : null,
      pendingRequestCount: (count?['requests'] as num?)?.toInt(),
    );
  }
}
