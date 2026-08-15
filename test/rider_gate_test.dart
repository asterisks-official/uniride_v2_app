import 'package:flutter_test/flutter_test.dart';
import 'package:uniride_app/features/auth/domain/models/user.dart';
import 'package:uniride_app/features/auth/presentation/providers/auth_notifier.dart';

User _user({required bool signedUpAsRider, String role = 'PASSENGER'}) => User(
      id: 'u1',
      name: 'Shakib Ahmed',
      email: 'shakib@diu.edu.bd',
      role: role,
      isEmailVerified: true,
      signedUpAsRider: signedUpAsRider,
    );

void main() {
  group('who gets checked', () {
    test('a rider signup awaiting approval does', () {
      expect(riderGateNeedsCheck(_user(signedUpAsRider: true)), isTrue);
    });

    test('an approved rider does not — the role is proof enough', () {
      // Also what keeps an offline launch from locking a working rider out.
      expect(
        riderGateNeedsCheck(_user(signedUpAsRider: true, role: 'RIDER')),
        isFalse,
      );
    });

    test('a passenger signup does not, even after applying by hand', () {
      // Applying voluntarily from Profile must not cost them the app they were
      // already using.
      expect(riderGateNeedsCheck(_user(signedUpAsRider: false)), isFalse);
    });
  });

  group('what the status means', () {
    test('no application yet locks them on the form', () {
      expect(riderGateForStatus(null), RiderGate.locked);
    });

    test('under review keeps them locked', () {
      expect(riderGateForStatus('PENDING'), RiderGate.locked);
    });

    test('approved opens the app', () {
      expect(riderGateForStatus('APPROVED'), RiderGate.open);
    });

    test('rejected keeps them locked, on the correction form', () {
      // A rejection comes with a reason and another attempt, so it is not a
      // way into the app. Nobody is stranded by this: an applicant who runs
      // out of attempts is blocked at the account level and cannot sign in at
      // all, so they never reach this screen.
      expect(riderGateForStatus('REJECTED'), RiderGate.locked);
    });

    test('an unrecognised status is treated as not approved', () {
      expect(riderGateForStatus('SOMETHING_NEW'), RiderGate.locked);
    });
  });
}
