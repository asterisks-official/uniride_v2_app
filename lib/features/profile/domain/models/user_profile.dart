class UserStats {
  const UserStats({
    required this.ridesCompleted,
    required this.ridesCancelled,
    required this.totalRatings,
    required this.averageRating,
    required this.trustScore,
  });

  final int ridesCompleted;
  final int ridesCancelled;
  final int totalRatings;
  final double averageRating;
  final int trustScore;

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        ridesCompleted: (json['ridesCompleted'] as num?)?.toInt() ?? 0,
        ridesCancelled: (json['ridesCancelled'] as num?)?.toInt() ?? 0,
        totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
        trustScore: (json['trustScore'] as num?)?.toInt() ?? 50,
      );
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isEmailVerified,
    this.phone,
    this.profilePictureUrl,
    this.university,
    this.bio,
    this.stats,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final bool isEmailVerified;
  final String? phone;
  final String? profilePictureUrl;
  final String? university;
  final String? bio;
  final UserStats? stats;

  bool get isRider => role == 'RIDER';

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
        isEmailVerified: json['isEmailVerified'] as bool? ?? false,
        phone: json['phone'] as String?,
        profilePictureUrl: json['profilePictureUrl'] as String?,
        university: json['university'] as String?,
        bio: json['bio'] as String?,
        stats: json['stats'] is Map<String, dynamic>
            ? UserStats.fromJson(json['stats'] as Map<String, dynamic>)
            : null,
      );
}
