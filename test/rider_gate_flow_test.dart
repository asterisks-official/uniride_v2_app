import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/core/di/providers.dart';
import 'package:uniride_app/core/router/app_router.dart';
import 'package:uniride_app/core/storage/secure_storage.dart';
import 'package:uniride_app/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:uniride_app/features/auth/data/repositories/auth_repository.dart';
import 'package:uniride_app/features/auth/domain/models/user.dart';
import 'package:uniride_app/features/auth/presentation/providers/auth_notifier.dart';
import 'package:uniride_app/features/rider/data/datasources/rider_remote_datasource.dart';
import 'package:uniride_app/features/rider/data/repositories/rider_repository.dart';
import 'package:uniride_app/features/rider/domain/models/rider_profile.dart';
import 'package:uniride_app/shared/exceptions/app_exception.dart';

User _user({bool signedUpAsRider = false, String role = 'PASSENGER'}) => User(
  id: 'u1',
  name: 'Shakib Ahmed',
  email: 'shakib@diu.edu.bd',
  role: role,
  isEmailVerified: true,
  signedUpAsRider: signedUpAsRider,
);

RiderProfile _profile(String status) => RiderProfile(
  id: 'p1',
  vehicleType: 'motorcycle',
  vehicleMake: 'Honda',
  vehicleModel: 'CB Hornet',
  vehicleYear: 2022,
  vehicleColor: 'Red',
  licensePlate: 'DHA-1234',
  verificationStatus: status,
);

/// Returns a fixed session instead of touching storage or the network.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this.user)
    : super(
        remote: AuthRemoteDataSource(Dio()),
        storage: SecureStorage(const FlutterSecureStorage()),
      );

  final User? user;

  @override
  Future<User?> tryRestoreSession() async => user;
}

/// Returns a fixed application state, or throws to stand in for being offline.
class _FakeRiderRepository extends RiderRepository {
  _FakeRiderRepository({this.profile, this.throws = false})
    : super(RiderRemoteDataSource(Dio()));

  final RiderProfile? profile;
  final bool throws;

  @override
  Future<RiderProfile?> getProfile() async {
    if (throws) throw const NetworkException('offline');
    return profile;
  }
}

ProviderContainer _container({
  required User? user,
  RiderProfile? profile,
  bool offline = false,
}) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(user)),
      riderRepositoryProvider.overrideWithValue(
        _FakeRiderRepository(profile: profile, throws: offline),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Lets the notifier's async bootstrap finish.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a rider under review is held on the application', () async {
    final container = _container(
      user: _user(signedUpAsRider: true),
      profile: _profile('PENDING'),
    );
    container.listen(authNotifierProvider, (_, _) {});

    await _settle();
    await _settle();

    final auth = container.read(authNotifierProvider);
    expect(auth, isA<Authenticated>());
    expect((auth as Authenticated).riderGate, RiderGate.locked);
    expect(authRedirect(auth, '/home'), '/verification');
  });

  test('a rider who has not applied yet is held too', () async {
    final container = _container(user: _user(signedUpAsRider: true));
    container.listen(authNotifierProvider, (_, _) {});

    await _settle();
    await _settle();

    final auth = container.read(authNotifierProvider) as Authenticated;
    expect(auth.riderGate, RiderGate.locked);
  });

  test('an approved rider gets in without a status lookup', () async {
    // The repository would throw if it were consulted, which is the point:
    // a granted RIDER role settles it, so an offline launch still works.
    final container = _container(
      user: _user(signedUpAsRider: true, role: 'RIDER'),
      offline: true,
    );
    container.listen(authNotifierProvider, (_, _) {});

    await _settle();
    await _settle();

    final auth = container.read(authNotifierProvider) as Authenticated;
    expect(auth.riderGate, RiderGate.open);
    expect(authRedirect(auth, '/home'), isNull);
  });

  test('a passenger is never held', () async {
    final container = _container(user: _user());
    container.listen(authNotifierProvider, (_, _) {});

    await _settle();
    await _settle();

    final auth = container.read(authNotifierProvider) as Authenticated;
    expect(auth.riderGate, RiderGate.open);
    expect(authRedirect(auth, '/home'), isNull);
  });

  test('an unreachable server holds the rider rather than letting them in',
      () async {
    final container = _container(
      user: _user(signedUpAsRider: true),
      offline: true,
    );
    container.listen(authNotifierProvider, (_, _) {});

    await _settle();
    await _settle();

    final auth = container.read(authNotifierProvider) as Authenticated;
    expect(auth.riderGate, RiderGate.locked);
  });

  test('no session lands on login', () async {
    final container = _container(user: null);
    container.listen(authNotifierProvider, (_, _) {});

    await _settle();

    expect(container.read(authNotifierProvider), isA<Unauthenticated>());
  });
}
