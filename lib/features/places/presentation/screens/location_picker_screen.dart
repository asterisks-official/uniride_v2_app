import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/exceptions/app_exception.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snack.dart';
import '../../../../shared/widgets/motion.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../domain/models/place_suggestion.dart';
import '../../domain/models/saved_place.dart';
import '../providers/geocoding_provider.dart';
import '../providers/saved_places_notifier.dart';
import '../widgets/save_place_sheet.dart';

/// Choose a point. The map is the screen, not a place you go from it.
///
/// An earlier version put a list in front of the map: pick an area by name,
/// get that area's coordinate. That was wrong twice over. It buried the map
/// behind an extra tap, and an area centroid is not a location — "Mirpur 10"
/// can be half a kilometre from the gate you actually wait at, which is both
/// the wrong fare and the wrong place for a rider to look for you.
///
/// So the map is always up, the pin is always live, and **the coordinate that
/// leaves this screen is always the one under the pin.** Search and saved
/// places move the map; they never answer for it. The one exception is a saved
/// place, which is a point this user pinned themselves and is therefore exact
/// already.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.title,
    this.initial,
    this.locateOnOpen = false,
  });

  final String title;
  final LatLng? initial;

  /// Fly to the device's position as soon as the screen opens.
  ///
  /// For "where are you now?", which has exactly one right answer: where the
  /// phone is. Off by default — a destination is somewhere you are *not*, so
  /// centring it on the user would be actively unhelpful.
  final bool locateOnOpen;

  static Future<PickedPlace?> open(
    BuildContext context, {
    required String title,
    LatLng? initial,
    bool locateOnOpen = false,
  }) {
    return Navigator.of(context).push<PickedPlace>(
      MaterialPageRoute<PickedPlace>(
        fullscreenDialog: true,
        builder: (_) => LocationPickerScreen(
          title: title,
          initial: initial,
          locateOnOpen: locateOnOpen,
        ),
      ),
    );
  }

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  static const _dhaka = LatLng(23.7806, 90.4074);

  /// Reverse geocoding is billed per call, so a continuous pan waits this long
  /// after the camera stops before asking what it landed on.
  static const _labelDebounce = Duration(milliseconds: 450);

  /// Autocomplete likewise: one request per typed word, not per keystroke.
  static const _searchDebounce = Duration(milliseconds: 350);

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  final MapController _map = MapController();
  late LatLng _centre = widget.initial ?? _dhaka;

  Timer? _labelTimer;
  Timer? _searchTimer;

  String _query = '';
  String? _label;
  bool _moving = false;
  bool _resolving = false;
  bool _locating = false;

  bool get _searching => _searchCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
    // Alongside the fix rather than after it: a cold GPS start takes seconds,
    // and the screen must be usable — labelled pin, live confirm button —
    // from the first frame either way.
    _requestLabel();
    if (widget.locateOnOpen) unawaited(_autoLocate());
  }

  /// Centres on the user as the screen opens.
  ///
  /// Silent on failure, unlike the button. The prompt is raised because they
  /// tapped a field that asks where they are, which is as concrete a reason
  /// as the crosshair itself — but a screen that greets a refusal with a
  /// snackbar is nagging, and the map still drags either way.
  Future<void> _autoLocate() async {
    setState(() => _locating = true);
    final result = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);

    if (result is! LocationFound) return;
    // A fix that lands after the user has started panning or typing is stale
    // news, and yanking the map out from under them is worse than not moving.
    if (_moving || _searching) return;
    await _flyTo(LatLng(result.lat, result.lng), zoom: 17);
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    _searchTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  // ── Map ────────────────────────────────────────────────────────────────────

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _centre = camera.center;
    if (hasGesture && !_moving) setState(() => _moving = true);
  }

  /// Settles only once the gesture *and* its momentum are done — otherwise the
  /// label flickers back mid-fling and reads as settled before it is.
  void _onMapEvent(MapEvent event) {
    if (event is! MapEventMoveEnd && event is! MapEventFlingAnimationEnd) {
      return;
    }
    if (mounted) setState(() => _moving = false);
    _labelTimer?.cancel();
    _labelTimer = Timer(_labelDebounce, _requestLabel);
  }

  Future<void> _requestLabel() async {
    final target = _centre;
    final label = await ref
        .read(geocodingRepositoryProvider)
        .reverse(target.latitude, target.longitude);

    // A later pan may have landed while this was in flight; that one owns the
    // label now.
    if (!mounted || target != _centre) return;
    setState(() => _label = label);
  }

  /// Moves the map somewhere without answering for it — the user still has to
  /// confirm whatever the pin ends up over.
  Future<void> _flyTo(LatLng target, {double zoom = 16}) async {
    _searchFocus.unfocus();
    _searchCtrl.clear();
    setState(() {
      _query = '';
      // Adopt the target immediately rather than waiting for the camera to
      // report it. If the controller is null — no API key, or the map failed
      // to initialise — `animateCamera` is a no-op and `onCameraIdle` never
      // fires, which would otherwise strand the pin with no label and leave
      // the confirm button dead with no way to recover.
      _centre = target;
      _label = null;
    });
    _map.move(target, zoom);
    await _requestLabel();
  }

  /// Centres the map on the user.
  ///
  /// The only place in this screen that can raise a permission prompt, and it
  /// is raised because they tapped a button that plainly needs location —
  /// never on open. Denial is not a failure state here: the map still drags,
  /// so the message says so rather than treating it as an error.
  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);

    final result = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);

    switch (result) {
      case LocationFound(:final lat, :final lng):
        await _flyTo(LatLng(lat, lng), zoom: 17);
      case LocationDenied(:final message, :final needsSettings):
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.dark,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              content: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              action: needsSettings
                  ? SnackBarAction(
                      label: 'Settings',
                      textColor: Colors.white,
                      onPressed: ref.read(locationServiceProvider).openSettings,
                    )
                  : null,
            ),
          );
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void _onSearchChanged(String value) {
    setState(() {});
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _openSuggestion(PlaceSuggestion suggestion) async {
    if (_resolving) return;
    setState(() => _resolving = true);

    final place = await ref
        .read(geocodingRepositoryProvider)
        .resolve(suggestion);

    if (!mounted) return;
    setState(() => _resolving = false);

    if (place == null) {
      showAppSnack(
        context,
        'Could not find that place. Try dropping the pin instead.',
        isError: true,
      );
      return;
    }
    // Deliberately not returning here: a search result is an approximation —
    // a building's front door, or the middle of a neighbourhood. The user
    // still adjusts and confirms.
    await _flyTo(LatLng(place.lat, place.lng));
  }

  // ── Confirm ────────────────────────────────────────────────────────────────

  void _confirmPin() {
    final label = _label;
    if (label == null) return;
    Navigator.of(context).pop(
      PickedPlace(
        lat: double.parse(_centre.latitude.toStringAsFixed(6)),
        lng: double.parse(_centre.longitude.toStringAsFixed(6)),
        label: label,
        areaLabel: label,
      ),
    );
  }

  /// A saved place is the one thing that can answer for the map: it is a point
  /// this user dropped themselves, so it is already exact.
  void _confirmSaved(SavedPlace place) =>
      Navigator.of(context).pop(PickedPlace.fromSaved(place));

  Future<void> _saveCurrentPin() async {
    final label = _label;
    if (label == null) return;
    final saved = await SavePlaceSheet.show(
      context,
      point: PickedPlace(
        lat: _centre.latitude,
        lng: _centre.longitude,
        label: label,
        areaLabel: label,
      ),
    );
    if (saved != null && mounted) Navigator.of(context).pop(saved);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final expanded = _searching || _searchFocus.hasFocus;
    final settled = !_moving && _label != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      // The search field lives in the bottom panel, so the body must rise
      // with the keyboard — otherwise the field would type invisibly
      // underneath it.
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Cap against what is actually left once the keyboard is up: the
          // panel must never swallow the map strip that keeps the back
          // button reachable and the pin visible.
          final panelHeight = math.min(
            expanded
                ? MediaQuery.sizeOf(context).height * 0.55
                // Tall enough that the saved list underneath is actually
                // usable — the search field, confirm button and hint alone
                // left room for barely one row at less than this.
                : 380.0,
            constraints.maxHeight - 96,
          );

          return Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FlutterMap(
                      mapController: _map,
                      options: MapOptions(
                        initialCenter: _centre,
                        initialZoom: widget.initial != null ? 16 : 13,
                        minZoom: 10,
                        maxZoom: 18,
                        onPositionChanged: _onPositionChanged,
                        onMapEvent: _onMapEvent,
                        interactionOptions: const InteractionOptions(
                          // No rotation: it does not help when the task is
                          // "put this dot on my gate", and a stray two-finger
                          // twist is hard to undo without a reset control.
                          flags:
                              InteractiveFlag.drag |
                              InteractiveFlag.pinchZoom |
                              InteractiveFlag.doubleTapZoom |
                              InteractiveFlag.flingAnimation,
                        ),
                      ),
                      children: const [_OsmTiles()],
                    ),

                    _CentrePin(lifted: _moving),

                    // The only chrome at the top: a way out. Everything that
                    // chooses a point lives in the panel below.
                    Positioned(
                      top: 0,
                      left: 14,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _MapButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ),
                    ),

                    const Positioned(
                      left: 8,
                      bottom: 8,
                      child: OsmAttribution(),
                    ),

                    // Hand-drawn so they match the app rather than the
                    // library's default chrome. Zoom is one grouped pill
                    // because + and − are one control, not two.
                    Positioned(
                      right: 14,
                      bottom: 16,
                      child: Column(
                        children: [
                          _MapButton(
                            icon: Icons.near_me_rounded,
                            busy: _locating,
                            onTap: _useMyLocation,
                          ),
                          const SizedBox(height: 10),
                          _ZoomPill(
                            onIn: () =>
                                _map.move(_centre, _map.camera.zoom + 1),
                            onOut: () =>
                                _map.move(_centre, _map.camera.zoom - 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                height: panelHeight,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.dark.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: AbsorbPointer(
                  absorbing: _resolving,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Grabber(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                          child: _SearchBar(
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            hint: widget.title,
                            editing: expanded,
                            onChanged: _onSearchChanged,
                            onClear: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                              _searchFocus.unfocus();
                            },
                          ),
                        ),
                        Expanded(
                          child: _searching
                              ? _searchResults()
                              : _pinPanel(settled),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Panels ─────────────────────────────────────────────────────────────────

  /// What the pin is currently over, how to keep it, and the saved places that
  /// would move it somewhere else.
  Widget _pinPanel(bool settled) {
    final places = ref.watch(savedPlacesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The headline: what the pin is over, said once and said large. The
        // address is the screen's subject, so it gets the weight rather than
        // sharing a row with a small icon and a hint.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: settled
                          ? Text(
                              _label!,
                              key: ValueKey(_label),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                height: 1.2,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : const SkeletonBox(width: 190, height: 21),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      // Says out loud that the pin wins, because the list
                      // underneath makes it look like the list might.
                      'Drag the map to move the pin.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CircleIconButton(
                icon: Icons.bookmark_add_outlined,
                tooltip: 'Save this place',
                onTap: settled ? _saveCurrentPin : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppButton(
            label: 'Confirm this point',
            icon: Icons.check_rounded,
            // Committing mid-pan captures wherever the map happened to be,
            // which is not a point anybody chose.
            onPressed: settled ? _confirmPin : null,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: places.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (list) => list.isEmpty
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 0, 20, 2),
                        child: _PanelLabel('Saved places'),
                      ),
                      for (final (i, place) in list.indexed)
                        _Row(
                          icon: _iconFor(place.label),
                          title: place.label,
                          subtitle: place.areaLabel,
                          // Hairline between rows only, inset to the text —
                          // a line under the last row would fence off the
                          // sheet's own edge.
                          divided: i != list.length - 1,
                          // Exact by construction — the user pinned it.
                          onTap: () => _confirmSaved(place),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _searchResults() {
    final results = ref.watch(placeSearchProvider(_query));

    return results.when(
      loading: () => ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        children: const [
          SkeletonBox(width: double.infinity, height: 46),
          SizedBox(height: 12),
          SkeletonBox(width: 240, height: 46),
        ],
      ),
      error: (e, _) => _Message(
        icon: Icons.cloud_off_rounded,
        title: 'Search is unavailable',
        detail: e is AppException ? e.message : 'Check your connection',
      ),
      data: (list) => list.isEmpty
          ? const _Message(
              icon: Icons.search_off_rounded,
              title: 'Nothing found',
              detail:
                  'Close the search and drag the pin instead — '
                  'that works anywhere.',
            )
          : ListView(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              children: [
                for (final (i, s) in list.indexed)
                  _Row(
                    icon: Icons.location_on_outlined,
                    title: s.primary,
                    subtitle: s.secondary,
                    divided: i != list.length - 1,
                    // Moves the map. Does not answer for it.
                    onTap: () => _openSuggestion(s),
                  ),
              ],
            ),
    );
  }

  static IconData _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('home') || l.contains('bari')) return Icons.home_rounded;
    if (l.contains('campus') || l.contains('uni') || l.contains('varsity')) {
      return Icons.school_rounded;
    }
    if (l.contains('work') || l.contains('office')) return Icons.work_rounded;
    return Icons.place_rounded;
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

/// OpenStreetMap tiles.
///
/// Development only: the public tile server is explicitly not licensed for
/// app-scale use, so this moves to a paid host or Google before release. It is
/// here because it renders with no key and no billing account, which is what
/// unblocks everything else. Attribution is a licence condition, not decoration.
class _OsmTiles extends StatelessWidget {
  const _OsmTiles();

  @override
  Widget build(BuildContext context) => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'bd.uniride.app',
    // Tiles are the one thing here that needs the network. When they fail the
    // map greys out but the pin, the coordinates and the confirm button all
    // still work.
    errorTileCallback: _ignoreTileError,
  );
}

void _ignoreTileError(TileImage _, Object _, StackTrace? _) {}

/// Required by the OpenStreetMap tile licence.
class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Text(
        '© OpenStreetMap',
        style: TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
      ),
    ),
  );
}

/// The pin, pinned. Lifts off its shadow while the map moves — the whole
/// feedback loop for "you are choosing whatever is under this".
class _CentrePin extends StatelessWidget {
  const _CentrePin({required this.lifted});

  final bool lifted;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pushes the pin down so its *tip* is at the centre of the map,
            // not its middle. Without this the chosen point sits ~22px north
            // of where it looks, which on a street is the wrong side of it.
            const SizedBox(height: 48),
            AnimatedSlide(
              offset: Offset(0, lifted ? -0.2 : 0),
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: const Icon(
                Icons.location_on,
                size: 48,
                color: AppColors.primary,
                shadows: [
                  Shadow(
                    color: Color(0x45000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              scale: lifted ? 0.55 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: Container(
                height: 7,
                width: 13,
                decoration: BoxDecoration(
                  color: AppColors.dark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The search field at the top of the panel.
///
/// Outlined by a hairline so it is visibly somewhere you can type — a bare
/// icon and hint on white left it reading as a caption. The outline is the
/// lightest thing that says "field": no fill, no shadow, and it takes the
/// brand colour on focus so the active state is unmistakable.
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.editing,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;

  /// Focused or carrying a query — the state that earns a way back out.
  final bool editing;

  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      height: 48,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        // No fill: the sheet is already white, and a grey slab here is the
        // heavy rectangle this screen just got rid of.
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? AppColors.primary : AppColors.border,
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(
              Icons.search_rounded,
              size: 21,
              // Follows the border, so the whole field lights up together.
              color: focused ? AppColors.primary : AppColors.muted,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14.5,
                ),
                isDense: true,
                // Every state, not just `border`: the app theme fills fields
                // and outlines them in all four states, and `border` alone is
                // only the fallback — the theme's enabled/focused outlines
                // would still draw a rectangle around the row.
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          // A filled glyph while there is something to clear, otherwise the
          // way back out of search. Never both — two controls that dismiss
          // the same thing is clutter, not choice.
          if (controller.text.isNotEmpty)
            _ClearGlyph(onTap: onClear)
          else if (editing)
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// The soft filled × that lives at the end of a search field.
class _ClearGlyph extends StatelessWidget {
  const _ClearGlyph({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Container(
        height: 20,
        width: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.muted.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
      ),
    ),
  );
}

/// A round control floating on the map. Circular rather than a rounded
/// square, so it reads as chrome hovering over the map instead of a card
/// sitting on it.
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => PressableScale(
    scale: 0.93,
    onTap: busy ? () {} : onTap,
    child: Container(
      height: 44,
      width: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: busy
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : Icon(icon, size: 19, color: AppColors.textPrimary),
    ),
  );
}

/// Zoom in and out as one grouped pill, split by a hairline — they are two
/// ends of a single control, and two separate floating buttons said otherwise.
class _ZoomPill extends StatelessWidget {
  const _ZoomPill({required this.onIn, required this.onOut});

  final VoidCallback onIn;
  final VoidCallback onOut;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: AppColors.dark.withValues(alpha: 0.14),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ZoomHalf(icon: Icons.add_rounded, onTap: onIn),
        Container(height: 1, width: 22, color: AppColors.border),
        _ZoomHalf(icon: Icons.remove_rounded, onTap: onOut),
      ],
    ),
  );
}

class _ZoomHalf extends StatelessWidget {
  const _ZoomHalf({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: SizedBox(
      height: 43,
      width: 44,
      child: Icon(icon, size: 20, color: AppColors.textPrimary),
    ),
  );
}

/// A quiet round icon button for a secondary action inside the sheet.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// Null renders it disabled — the action is not available yet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        scale: 0.92,
        onTap: onTap ?? () {},
        child: Container(
          height: 40,
          width: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 19,
            color: enabled ? AppColors.textSecondary : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 5,
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.muted,
      ),
    ),
  );
}

/// One tappable place: a tinted round glyph, a name, and where it is.
///
/// The separator is drawn inside the row and inset past the glyph, so the
/// list reads as one grouped block rather than a stack of full-width rules.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.divided = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool divided;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      scale: 0.99,
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryWash,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 19, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
          if (divided)
            Container(
              height: 1,
              margin: const EdgeInsets.only(left: 72, right: 20),
              color: AppColors.border,
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
    child: Column(
      children: [
        Container(
          height: 56,
          width: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.background,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 26, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
