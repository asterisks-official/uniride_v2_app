/// One row in the place-search results.
///
/// Coordinates are usually absent — Google's autocomplete returns an id and
/// two strings, and resolving it to a point is a second, separately billed
/// call. So the search list is cheap and only the row the user actually taps
/// costs anything.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.id,
    required this.primary,
    required this.secondary,
    this.lat,
    this.lng,
  });

  /// A Google place id, or `area:<name>` when the server answered from its
  /// static fallback list.
  final String id;

  /// The bold line — "Daffodil International University".
  final String primary;

  /// The line underneath — "Ashulia, Savar".
  final String secondary;

  /// Set only when the server already knew the point, which is the case for
  /// fallback areas. Saves a resolve call.
  final double? lat;
  final double? lng;

  bool get isResolved => lat != null && lng != null;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) =>
      PlaceSuggestion(
        id: json['id'] as String,
        primary: json['primary'] as String? ?? '',
        secondary: json['secondary'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
      );
}
