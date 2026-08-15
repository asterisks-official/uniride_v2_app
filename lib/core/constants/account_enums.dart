/// Account-level enums mirroring the backend's Prisma enums.
///
/// Kept in `core` rather than a feature folder because signup, profile, and the
/// rides feed all need them, and none of those should depend on each other.
library;

/// The user's own gender. Distinct from a ride's gender preference — this is
/// what makes a female-only ride enforceable rather than advisory.
enum Gender {
  male('MALE', 'Male'),
  female('FEMALE', 'Female'),
  other('OTHER', 'Other');

  const Gender(this.wire, this.label);

  /// Value the API expects.
  final String wire;
  final String label;

  static Gender? fromWire(String? v) {
    if (v == null) return null;
    for (final g in Gender.values) {
      if (g.wire == v) return g;
    }
    return null;
  }
}

/// Which side the user is signing up for.
///
/// Choosing [rider] does not grant the rider role — it starts the application,
/// which an admin still has to approve. The account is created in passenger
/// mode either way.
enum JoinAs {
  passenger('PASSENGER'),
  rider('RIDER');

  const JoinAs(this.wire);
  final String wire;
}

/// Which side of the market the user is currently browsing.
///
/// Separate from their role: role is the admin-granted capability, this is the
/// view they chose. An approved rider browsing as a passenger is a student who
/// needs a lift today.
enum ActiveMode {
  passenger('PASSENGER', 'Passenger'),
  rider('RIDER', 'Rider');

  const ActiveMode(this.wire, this.label);

  final String wire;
  final String label;

  static ActiveMode fromWire(String? v) =>
      v == 'RIDER' ? ActiveMode.rider : ActiveMode.passenger;
}
