/// One end of every university commute.
///
/// The reason ride creation asks for a single point plus a direction rather
/// than two addresses: one end is always this.
class Campus {
  const Campus({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;

  factory Campus.fromJson(Map<String, dynamic> json) => Campus(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String? ?? '',
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
  );
}

/// A university and the campuses the caller may post rides to.
class University {
  const University({
    required this.id,
    required this.shortName,
    required this.campuses,
  });

  final String id;
  final String shortName;
  final List<Campus> campuses;

  factory University.fromJson(Map<String, dynamic> json) => University(
    id: json['id'] as String,
    shortName: json['shortName'] as String? ?? '',
    campuses:
        (json['campuses'] as List<dynamic>? ?? const [])
            .map((e) => Campus.fromJson(e as Map<String, dynamic>))
            .toList(),
  );
}
