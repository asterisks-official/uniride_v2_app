import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/models/place_suggestion.dart';

export '../../../../core/di/providers.dart' show geocodingRepositoryProvider;

/// Search results for a query, debounced by the caller.
///
/// A family rather than a notifier so Riverpod caches per query string: typing
/// "mir", "mirp", "mirpu", "mirpur" and then deleting back to "mirp" costs one
/// request, not five. Autocomplete is billed per call, so that matters.
///
/// `autoDispose` keeps the cache to the lifetime of the picker sheet — place
/// results go stale and holding every query a user has ever typed is not worth
/// the memory.
final placeSearchProvider = FutureProvider.autoDispose
    .family<List<PlaceSuggestion>, String>((ref, query) async {
      final q = query.trim();
      // Two characters is where results stop being noise.
      if (q.length < 2) return const [];
      return ref.read(geocodingRepositoryProvider).search(q);
    });
