import 'package:flutter/material.dart';

enum TripStatus { assigned, enRoute, arrived, completed, cancelled }

enum RideType {
  standard,
  wheelchair,
  stretcher;

  String get displayName {
    switch (this) {
      case RideType.standard:
        return 'Standard';
      case RideType.wheelchair:
        return 'Wheelchair';
      case RideType.stretcher:
        return 'Stretcher';
    }
  }

  IconData get icon {
    switch (this) {
      case RideType.standard:
        return Icons.directions_car_rounded;
      case RideType.wheelchair:
        return Icons.accessible_forward_rounded;
      case RideType.stretcher:
        return Icons.medical_services_rounded;
    }
  }
}

class AssignedTrip {
  final String id;
  final String patientName;
  final String patientPhone;
  final String pickupAddress;
  final String destinationAddress;
  final DateTime scheduledTime;
  final RideType rideType;
  final double distanceKm;
  final double fare;
  final TripStatus status;
  final String? notes;
  final DateTime assignedAt;

  const AssignedTrip({
    required this.id,
    required this.patientName,
    required this.patientPhone,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.scheduledTime,
    required this.rideType,
    required this.distanceKm,
    required this.fare,
    required this.status,
    this.notes,
    required this.assignedAt,
  });

  factory AssignedTrip.fromJson(Map<String, dynamic> json) {
    return AssignedTrip(
      id: json['id'] as String,
      patientName: json['patient_name'] as String,
      patientPhone: json['patient_phone'] as String,
      pickupAddress: json['pickup_address'] as String,
      destinationAddress: json['destination_address'] as String,
      scheduledTime: DateTime.parse(json['scheduled_time'] as String),
      rideType: RideType.values.firstWhere(
        (type) => type.name == json['ride_type'],
        orElse: () => RideType.standard,
      ),
      distanceKm: (json['distance_km'] as num).toDouble(),
      fare: (json['fare'] as num).toDouble(),
      status: TripStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => TripStatus.assigned,
      ),
      notes: json['notes'] as String?,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_name': patientName,
    'patient_phone': patientPhone,
    'pickup_address': pickupAddress,
    'destination_address': destinationAddress,
    'scheduled_time': scheduledTime.toIso8601String(),
    'ride_type': rideType.name,
    'distance_km': distanceKm,
    'fare': fare,
    'status': status.name,
    'notes': notes,
    'assigned_at': assignedAt.toIso8601String(),
  };

  AssignedTrip copyWith({
    String? id,
    String? patientName,
    String? patientPhone,
    String? pickupAddress,
    String? destinationAddress,
    DateTime? scheduledTime,
    RideType? rideType,
    double? distanceKm,
    double? fare,
    TripStatus? status,
    String? notes,
    DateTime? assignedAt,
  }) {
    return AssignedTrip(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      patientPhone: patientPhone ?? this.patientPhone,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      rideType: rideType ?? this.rideType,
      distanceKm: distanceKm ?? this.distanceKm,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      assignedAt: assignedAt ?? this.assignedAt,
    );
  }

  String get formattedFare => 'TZS ${fare.toStringAsFixed(0)}';
  String get formattedDistance => '${distanceKm.toStringAsFixed(1)} km';

  String get statusDisplayName {
    switch (status) {
      case TripStatus.assigned:
        return 'Assigned';
      case TripStatus.enRoute:
        return 'En Route';
      case TripStatus.arrived:
        return 'Arrived';
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get statusColor {
    switch (status) {
      case TripStatus.assigned:
        return const Color(0xFF3B82F6);
      case TripStatus.enRoute:
        return const Color(0xFFF97316);
      case TripStatus.arrived:
        return const Color(0xFFEF9F27);
      case TripStatus.completed:
        return const Color(0xFF1D9E75);
      case TripStatus.cancelled:
        return const Color(0xFFD85A30);
    }
  }
}
