/// What a trip costs, as the server computed it.
///
/// The client never derives a fare — it displays [total] and nothing else is
/// authoritative. The components are here only so the screen can show
/// "12.6 km · about 42 min" underneath; recombining them locally would let two
/// devices disagree about a price.
class RideQuote {
  const RideQuote({
    required this.distanceKm,
    required this.durationMin,
    required this.total,
    required this.currency,
    this.polyline = const [],
    this.minimumApplied = false,
  });

  final double distanceKm;
  final int durationMin;

  /// Whole taka. This is the number that gets stored on the ride.
  final int total;

  final String currency;

  /// The road the price was computed over, as (lat, lng) pairs.
  ///
  /// Empty when the server estimated rather than routed — the preview then
  /// draws a straight line, which is honest about not knowing the roads
  /// rather than implying a path nobody worked out.
  final List<(double, double)> polyline;

  /// True when the trip was short enough that the minimum set the price. Worth
  /// saying out loud — otherwise a 1 km and a 3 km trip costing the same reads
  /// as a bug.
  final bool minimumApplied;

  factory RideQuote.fromJson(Map<String, dynamic> json) => RideQuote(
    distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
    durationMin: (json['durationMin'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.round() ?? 0,
    currency: json['currency'] as String? ?? 'BDT',
    polyline:
        (json['polyline'] as List<dynamic>? ?? const [])
            .whereType<List<dynamic>>()
            .map((p) => ((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList(),
    minimumApplied: json['minimumApplied'] as bool? ?? false,
  );

  /// "৳239"
  String get formattedTotal => '৳$total';

  /// "12.6 km · about 42 min"
  String get summary {
    final km = distanceKm.toStringAsFixed(1);
    return '$km km · about $durationMin min';
  }
}
