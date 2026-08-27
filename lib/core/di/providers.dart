import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/rider/data/datasources/rider_remote_datasource.dart';
import '../../features/rider/data/repositories/rider_repository.dart';
import '../../features/rides/data/datasources/rides_remote_datasource.dart';
import '../../features/rides/data/repositories/rides_repository.dart';
import '../../features/places/data/datasources/places_remote_datasource.dart';
import '../../features/places/data/repositories/places_repository.dart';
import '../../features/places/data/repositories/geocoding_repository.dart';
import '../../features/ratings/data/ratings_repository.dart';
import '../../features/drivers/data/repositories/drivers_repository.dart';
import '../network/api_client.dart';
import '../realtime/realtime_service.dart';
import '../storage/secure_storage.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(const FlutterSecureStorage());
});

/// The live channel. Connected once, kept for the app's lifetime — the feed
/// and anything else that wants server pushes listen to the same socket.
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  final service = RealtimeService(ref.watch(secureStorageProvider));
  ref.onDispose(service.dispose);
  return service;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    storage: ref.watch(secureStorageProvider),
    onSessionExpired: () =>
        ref.read(authNotifierProvider.notifier).onSessionExpired(),
  );
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider).dio);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    remote: ref.watch(authRemoteDataSourceProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

final riderRemoteDataSourceProvider = Provider<RiderRemoteDataSource>((ref) {
  return RiderRemoteDataSource(ref.watch(apiClientProvider).dio);
});

final riderRepositoryProvider = Provider<RiderRepository>((ref) {
  return RiderRepository(ref.watch(riderRemoteDataSourceProvider));
});

final ridesRemoteDataSourceProvider = Provider<RidesRemoteDataSource>((ref) {
  return RidesRemoteDataSource(ref.watch(apiClientProvider).dio);
});

final ratingsRepositoryProvider = Provider<RatingsRepository>((ref) {
  return RatingsRepository(ref.watch(apiClientProvider).dio);
});

final ridesRepositoryProvider = Provider<RidesRepository>((ref) {
  return RidesRepository(ref.watch(ridesRemoteDataSourceProvider));
});

final placesRemoteDataSourceProvider = Provider<PlacesRemoteDataSource>((ref) {
  return PlacesRemoteDataSource(ref.watch(apiClientProvider).dio);
});

final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  return PlacesRepository(ref.watch(placesRemoteDataSourceProvider));
});

final geocodingRepositoryProvider = Provider<GeocodingRepository>((ref) {
  return GeocodingRepository(ref.watch(apiClientProvider).dio);
});

final driversRepositoryProvider = Provider<DriversRepository>((ref) {
  return DriversRepository(ref.watch(apiClientProvider).dio);
});
