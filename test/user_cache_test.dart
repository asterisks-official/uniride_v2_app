import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/core/storage/secure_storage.dart';
import 'package:uniride_app/features/auth/domain/models/user.dart';

const _riderSignup = User(
  id: 'u1',
  name: 'Shakib Ahmed',
  email: 'shakib@diu.edu.bd',
  role: 'PASSENGER',
  isEmailVerified: true,
  signedUpAsRider: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SecureStorage storageWith(Map<String, String> initial) {
    FlutterSecureStorage.setMockInitialValues(initial);
    return SecureStorage(const FlutterSecureStorage());
  }

  test('a user cached by this build is read back', () async {
    final storage = storageWith({});
    await storage.saveUserJson(jsonEncode(_riderSignup.toJson()));

    final json = await storage.readUserJson();
    expect(json, isNotNull);
    expect(
      User.fromJson(jsonDecode(json!) as Map<String, dynamic>).signedUpAsRider,
      isTrue,
    );
  });

  test('a cache written before signedUpAsRider existed is discarded', () async {
    // Exactly what an install from before that field had on disk. Decoding it
    // yields signedUpAsRider: false, which told the router a rider with an
    // application under review was an ordinary passenger and let them in.
    final storage = storageWith({
      'user_json': jsonEncode({
        'id': 'u1',
        'name': 'Shakib Ahmed',
        'email': 'shakib@diu.edu.bd',
        'role': 'PASSENGER',
        'isEmailVerified': true,
      }),
    });

    expect(
      await storage.readUserJson(),
      isNull,
      reason: 'no version marker means the cache predates this User shape',
    );
  });

  test('a cache from a different version is discarded', () async {
    final storage = storageWith({
      'user_json': jsonEncode(_riderSignup.toJson()),
      'user_json_version': '1',
    });

    expect(await storage.readUserJson(), isNull);
  });

  test('signing out drops the version marker too', () async {
    final storage = storageWith({});
    await storage.saveUserJson(jsonEncode(_riderSignup.toJson()));
    await storage.clear();

    // A leftover marker would validate the *next* account's stale cache.
    expect(await storage.readUserJson(), isNull);
    await storage.saveUserJson(jsonEncode(_riderSignup.toJson()));
    expect(await storage.readUserJson(), isNotNull);
  });
}
