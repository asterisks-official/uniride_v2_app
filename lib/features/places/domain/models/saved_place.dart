/// A point the user has named, so posting a ride never needs a map twice.
///
/// The coordinates are what a ride is created with; the [areaLabel] is what
/// other people see. Those are deliberately different granularities — the
/// platform shows a coarse area until both sides have committed to a ride.
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    required this.areaLabel,
    this.lastUsedAt,
  });

  final String id;

  /// The user's own name for it — "Home", "Nani's".
  final String label;

  final double lat;
  final double lng;

  /// Coarse area, e.g. "Mirpur 10".
  final String areaLabel;

  /// Bumped server-side when a ride is posted from here, so the compose screen
  /// can default to the place someone actually uses.
  final DateTime? lastUsedAt;

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
    id: json['id'] as String,
    label: json['label'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    areaLabel: json['areaLabel'] as String? ?? '',
    lastUsedAt: json['lastUsedAt'] != null
        ? DateTime.tryParse(json['lastUsedAt'] as String)
        : null,
  );
}

/// A point chosen anywhere in the picker chain — a saved place, a searched
/// area, or a pin dropped on the map.
///
/// The compose screen only ever needs these three fields, so it takes this
/// rather than a [SavedPlace]: a one-off trip from a dropped pin is not a
/// saved place and should not have to pretend to be one.
class PickedPlace {
  const PickedPlace({
    required this.lat,
    required this.lng,
    required this.areaLabel,
    this.savedPlaceId,
    this.label,
  });

  final double lat;
  final double lng;
  final String areaLabel;

  /// Set when the pick came from the saved list.
  final String? savedPlaceId;

  /// The saved name, when there is one. Falls back to [areaLabel] for display.
  final String? label;

  String get displayName => label ?? areaLabel;

  factory PickedPlace.fromSaved(SavedPlace place) => PickedPlace(
    lat: place.lat,
    lng: place.lng,
    areaLabel: place.areaLabel,
    savedPlaceId: place.id,
    label: place.label,
  );
}
