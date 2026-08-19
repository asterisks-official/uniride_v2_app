/// Whether this rider is available to be dispatched to.
class DriverAvailability {
  const DriverAvailability({
    required this.isOnline,
    required this.dispatchable,
    this.lat,
    this.lng,
    this.lastSeenAt,
    this.activeRideId,
  });

  /// What the rider asked for.
  final bool isOnline;

  /// What the server will actually act on: online *and* recently seen.
  ///
  /// These come apart when the app is killed or loses signal mid-shift — the
  /// flag stays true with nothing to correct it, so the server stops trusting
  /// it after a couple of minutes without a heartbeat. Worth surfacing rather
  /// than hiding: a rider who thinks they are online and is getting no trips
  /// deserves to know which of the two is false.
  final bool dispatchable;

  final double? lat;
  final double? lng;
  final DateTime? lastSeenAt;

  /// Set while carrying a passenger. Dispatch skips them.
  final String? activeRideId;

  bool get onTrip => activeRideId != null;

  /// Online, but the server has stopped counting them — the state worth
  /// warning about.
  bool get stale => isOnline && !dispatchable && !onTrip;

  static const offline = DriverAvailability(
    isOnline: false,
    dispatchable: false,
  );

  factory DriverAvailability.fromJson(Map<String, dynamic> json) =>
      DriverAvailability(
        isOnline: json['isOnline'] as bool? ?? false,
        dispatchable: json['dispatchable'] as bool? ?? false,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        lastSeenAt: json['lastSeenAt'] != null
            ? DateTime.tryParse(json['lastSeenAt'] as String)
            : null,
        activeRideId: json['activeRideId'] as String?,
      );
}
