import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../places/presentation/screens/location_picker_screen.dart'
    show OsmAttribution;

/// The trip drawn on a map, filling whatever it is given.
///
/// Non-interactive on purpose. The moment it can be dragged, people try to set
/// their pickup on it, and the picker is a far better tool for that — this is
/// here to show the trip, not to collect one.
class TripMap extends StatefulWidget {
  const TripMap({
    super.key,
    required this.origin,
    required this.destination,
    this.route = const [],
    this.padding = const EdgeInsets.all(34),
    this.pulse = false,
  });

  final LatLng origin;
  final LatLng destination;

  /// The road between the ends. Empty until the quote lands, or when the
  /// server estimated the distance rather than routing it.
  final List<LatLng> route;

  /// Room left around the trip. A tall map wants more at the bottom, where a
  /// sheet may be overlapping it.
  final EdgeInsets padding;

  /// Run a light travelling the route, and rings out from the pickup.
  ///
  /// For a trip that is waiting on somebody. It says the route is being shown
  /// to people right now, which a static line cannot — and it stops the
  /// moment the trip has an answer, so the motion always means "still open".
  final bool pulse;

  @override
  State<TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<TripMap> with SingleTickerProviderStateMixin {
  final MapController _controller = MapController();

  // Built eagerly, not lazily: a `late` controller that no frame ever touches
  // gets constructed by `dispose()` itself, and creating a Ticker against a
  // deactivated element trips an assertion on the way out.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    if (widget.pulse) _pulse.repeat();
  }

  @override
  void didUpdateWidget(covariant TripMap old) {
    super.didUpdateWidget(old);
    if (old.origin != widget.origin ||
        old.destination != widget.destination ||
        old.route.length != widget.route.length) {
      _fit();
    }
    if (old.pulse != widget.pulse) {
      // Stopped rather than left spinning: an animation nobody can see still
      // costs a frame every 16ms.
      widget.pulse ? _pulse.repeat() : _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// The path the light runs along — the real road when there is one, the
  /// straight line between the ends otherwise.
  List<LatLng> get _path => widget.route.isNotEmpty
      ? widget.route
      : [widget.origin, widget.destination];

  /// The point [t] of the way along [_path], measured by distance rather than
  /// by index — segments are wildly uneven, and stepping per-index would make
  /// the light crawl through junctions and leap down straights.
  LatLng _pointAt(double t) {
    final path = _path;
    if (path.length < 2) return path.first;

    final spans = <double>[];
    var total = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      final dx = path[i + 1].longitude - path[i].longitude;
      final dy = path[i + 1].latitude - path[i].latitude;
      final d = math.sqrt(dx * dx + dy * dy);
      spans.add(d);
      total += d;
    }
    if (total == 0) return path.first;

    var travelled = t.clamp(0.0, 1.0) * total;
    for (var i = 0; i < spans.length; i++) {
      if (travelled <= spans[i] || i == spans.length - 1) {
        final f = spans[i] == 0 ? 0.0 : (travelled / spans[i]).clamp(0.0, 1.0);
        return LatLng(
          path[i].latitude + (path[i + 1].latitude - path[i].latitude) * f,
          path[i].longitude + (path[i + 1].longitude - path[i].longitude) * f,
        );
      }
      travelled -= spans[i];
    }
    return path.last;
  }

  /// True before both ends are chosen, when they collapse onto one point.
  ///
  /// Fitting a camera to zero-sized bounds asks for infinite zoom, which
  /// throws `Infinity or NaN toInt` deep inside the tile layer and takes the
  /// whole screen with it.
  bool get _degenerate =>
      widget.route.isEmpty && widget.origin == widget.destination;

  /// Frames the whole route, not just its two ends — a road that loops north
  /// of both pins would otherwise run off the top of the box.
  CameraFit? get _cameraFit => _degenerate
      ? null
      : CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([
            widget.origin,
            widget.destination,
            ...widget.route,
          ]),
          padding: widget.padding,
        );

  void _fit() {
    final fit = _cameraFit;
    if (fit == null) return;
    // Throws if the map has not laid out yet, which happens on the first frame
    // after the ends change and is not worth a guard flag when the next frame
    // refits anyway.
    try {
      _controller.fitCamera(fit);
    } catch (_) {
      // Ignored.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Under the map, so unreachable tiles show a tinted panel rather than
        // a stark grey void.
        const ColoredBox(color: AppColors.primaryWash),

        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCameraFit: _cameraFit,
            // Used only when there is nothing to fit to yet.
            initialCenter: widget.origin,
            initialZoom: 13,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'bd.uniride.app',
              errorTileCallback: (_, _, _) {},
            ),
            PolylineLayer(
              polylines: [
                // Nothing to draw between a point and itself.
                if (_degenerate)
                  Polyline(points: [widget.origin])
                else if (widget.route.isNotEmpty)
                  // A real route: solid, because it *is* the road the fare was
                  // computed over.
                  Polyline(
                    points: widget.route,
                    color: AppColors.primary,
                    strokeWidth: 5,
                    borderColor: AppColors.surface,
                    borderStrokeWidth: 2,
                  )
                else
                  // No route yet, or the server estimated rather than routed.
                  // Dotted, so it reads as a claim about distance rather than
                  // about which streets to take.
                  Polyline(
                    points: [widget.origin, widget.destination],
                    color: AppColors.primary.withValues(alpha: 0.5),
                    strokeWidth: 3,
                    pattern: const StrokePattern.dotted(),
                  ),
              ],
            ),
            // Only this layer rebuilds per frame — wrapping the whole
            // FlutterMap would re-lay-out the tiles sixty times a second.
            if (widget.pulse && !_degenerate)
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.origin,
                      width: 96,
                      height: 96,
                      child: _OriginRings(t: _pulse.value),
                    ),
                    Marker(
                      point: _pointAt(Curves.easeInOut.transform(_pulse.value)),
                      width: 22,
                      height: 22,
                      child: _RouteLight(t: _pulse.value),
                    ),
                  ],
                ),
              ),

            MarkerLayer(
              markers: [
                // Nothing to mark while the ends are one point — two pins
                // stacked on the same coordinate read as a glitch.
                if (!_degenerate) ...[
                  Marker(
                    point: widget.origin,
                    width: 20,
                    height: 20,
                    child: const _Endpoint(color: AppColors.primary),
                  ),
                  Marker(
                    point: widget.destination,
                    width: 34,
                    height: 40,
                    // The destination gets a pin rather than a dot: on a map
                    // showing a journey, one end has to read as the arrival.
                    child: const _DestinationPin(),
                  ),
                ],
              ],
            ),
          ],
        ),

        const Positioned(left: 6, bottom: 6, child: OsmAttribution()),
      ],
    );
  }
}

/// Rings leaving the pickup, where the search is centred.
class _OriginRings extends StatelessWidget {
  const _OriginRings({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _RingPainter(t: t)),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.t});

  final double t;
  static const _rings = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final maxR = size.width / 2;

    for (var i = 0; i < _rings; i++) {
      final phase = (t + i / _rings) % 1.0;
      final radius = maxR * Curves.easeOutCubic.transform(phase);
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = AppColors.primary.withValues(alpha: (1 - phase) * 0.16),
      );
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.primary.withValues(alpha: (1 - phase) * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}

/// The light running the route.
///
/// Fades in and out at the ends of its run so it appears to set off and
/// arrive, rather than snapping back to the start every cycle.
class _RouteLight extends StatelessWidget {
  const _RouteLight({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final fade = (math.sin(t * math.pi)).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Center(
        child: Container(
          height: 13,
          width: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface.withValues(alpha: fade),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: fade),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: fade * 0.55),
                blurRadius: 9,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      border: Border.all(color: AppColors.surface, width: 3),
      boxShadow: [
        BoxShadow(
          color: AppColors.dark.withValues(alpha: 0.3),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
  );
}

class _DestinationPin extends StatelessWidget {
  const _DestinationPin();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.location_on,
    size: 36,
    color: AppColors.dark,
    shadows: [
      Shadow(color: Color(0x40000000), blurRadius: 5, offset: Offset(0, 2)),
    ],
  );
}
