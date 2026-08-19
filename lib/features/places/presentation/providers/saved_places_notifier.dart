import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/models/saved_place.dart';

/// The user's saved places, most recently used first.
///
/// Mutations reload rather than patching the list in place: the server owns
/// the ordering (`lastUsedAt`) and the cap, so a local edit would be guessing
/// at both.
class SavedPlacesNotifier extends AsyncNotifier<List<SavedPlace>> {
  @override
  Future<List<SavedPlace>> build() => _fetch();

  Future<List<SavedPlace>> _fetch() =>
      ref.read(placesRepositoryProvider).list();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Throws [AppException] on failure so the caller can surface the reason —
  /// hitting the saved-place cap is a message worth reading, not a silent
  /// no-op.
  Future<SavedPlace> add({
    required String label,
    required double lat,
    required double lng,
    required String areaLabel,
  }) async {
    final place = await ref
        .read(placesRepositoryProvider)
        .create(label: label, lat: lat, lng: lng, areaLabel: areaLabel);
    await reload();
    return place;
  }

  Future<void> rename(
    SavedPlace place, {
    required String label,
  }) async {
    await ref
        .read(placesRepositoryProvider)
        .update(
          place.id,
          label: label,
          lat: place.lat,
          lng: place.lng,
          areaLabel: place.areaLabel,
        );
    await reload();
  }

  Future<void> remove(String id) async {
    await ref.read(placesRepositoryProvider).remove(id);
    await reload();
  }
}

final savedPlacesProvider =
    AsyncNotifierProvider<SavedPlacesNotifier, List<SavedPlace>>(
      SavedPlacesNotifier.new,
    );
