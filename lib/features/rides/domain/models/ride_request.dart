import 'ride.dart';

class RideRequest {
  const RideRequest({
    required this.id,
    required this.rideId,
    required this.passengerId,
    required this.status,
    this.message,
    required this.createdAt,
    required this.expiresAt,
    this.passenger,
  });

  final String id;
  final String rideId;
  final String passengerId;
  final String status; // PENDING | ACCEPTED | DECLINED | EXPIRED
  final String? message;
  final DateTime createdAt;
  final DateTime expiresAt;

  // Present when fetched via GET /rides/:id/requests (includes passenger + stats).
  final RiderSummary? passenger;

  factory RideRequest.fromJson(Map<String, dynamic> json) {
    final passengerJson = json['passenger'] as Map<String, dynamic>?;
    return RideRequest(
      id: json['id'] as String,
      rideId: json['rideId'] as String,
      passengerId: json['passengerId'] as String,
      status: json['status'] as String? ?? 'PENDING',
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      passenger:
          passengerJson != null ? RiderSummary.fromJson(passengerJson) : null,
    );
  }
}
