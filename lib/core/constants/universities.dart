/// Universities a student can sign up under.
///
/// Hardcoded on purpose, for now. The backend has no `universities` table yet —
/// `User.university` is still free text — so this list is the single place the
/// app decides what is selectable. Keeping it here rather than inline in the
/// form means swapping to `GET /universities` later touches one file.
///
/// Only DIU is live. The launch bar is per-campus, not per-country: a campus
/// opens once enough drivers have been recruited by hand, so adding entries
/// here before that happens creates dead marketplaces.
library;

class UniversityOption {
  const UniversityOption({required this.name, required this.shortName});

  /// Stored on the user; the API takes free text today.
  final String name;
  final String shortName;
}

const kUniversities = <UniversityOption>[
  UniversityOption(
    name: 'Daffodil International University',
    shortName: 'DIU',
  ),
];

/// Shown as the last option so students at other campuses have somewhere to
/// land instead of abandoning signup. Expansion should be pull-based — driven
/// by who actually asks — rather than guessed.
const kOtherUniversityLabel = 'My university isn\'t listed yet';
