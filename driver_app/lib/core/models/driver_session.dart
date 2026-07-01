// ─────────────────────────────────────────────────────────────────────────────
// core/models/driver_session.dart
// Pure data models — no hardcoded values here.
// ─────────────────────────────────────────────────────────────────────────────

enum VehicleType { standard, ambulance, wheelchair }

enum TripAssignmentStatus {
  assigned,
  accepted,
  inProgress,
  arrived,
  completed,
  cancelled,
}

// ── VehicleType Extension ─────────────────────────────────────────────────────

extension VehicleTypeExtension on VehicleType {
  String get displayName {
    switch (this) {
      case VehicleType.standard:
        return 'Standard';
      case VehicleType.ambulance:
        return 'Ambulance';
      case VehicleType.wheelchair:
        return 'Wheelchair';
    }
  }
  
  String get icon {
    switch (this) {
      case VehicleType.standard:
        return '🚗';
      case VehicleType.ambulance:
        return '🚑';
      case VehicleType.wheelchair:
        return '♿';
    }
  }
}

// ── DriverAssignedTrip ────────────────────────────────────────────────────────

class DriverAssignedTrip {
  final String id;
  final String patientName;
  final String appointmentType;
  final String pickupAddress;
  final String destination;
  final String pickupTime;
  final List<String> specialRequirements;
  final TripAssignmentStatus status;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destLatitude;
  final double? destLongitude;
  final double? estimatedFare;
  final DateTime? completedAt;

  const DriverAssignedTrip({
    required this.id,
    required this.patientName,
    required this.appointmentType,
    required this.pickupAddress,
    required this.destination,
    required this.pickupTime,
    required this.specialRequirements,
    required this.status,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destLatitude,
    this.destLongitude,
    this.estimatedFare,
    this.completedAt,
  });

  DriverAssignedTrip copyWith({
    String? id,
    String? patientName,
    String? appointmentType,
    String? pickupAddress,
    String? destination,
    String? pickupTime,
    List<String>? specialRequirements,
    TripAssignmentStatus? status,
    double? pickupLatitude,
    double? pickupLongitude,
    double? destLatitude,
    double? destLongitude,
    double? estimatedFare,
    DateTime? completedAt,
  }) {
    return DriverAssignedTrip(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      appointmentType: appointmentType ?? this.appointmentType,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destination: destination ?? this.destination,
      pickupTime: pickupTime ?? this.pickupTime,
      specialRequirements: specialRequirements ?? this.specialRequirements,
      status: status ?? this.status,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      destLatitude: destLatitude ?? this.destLatitude,
      destLongitude: destLongitude ?? this.destLongitude,
      estimatedFare: estimatedFare ?? this.estimatedFare,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Convert model → Map (mirrors expected API response shape).
  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_name': patientName,
        'appointment_type': appointmentType,
        'pickup_address': pickupAddress,
        'destination': destination,
        'pickup_time': pickupTime,
        'special_requirements': specialRequirements,
        'status': status.name,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'destination_latitude': destLatitude,
        'destination_longitude': destLongitude,
        'estimated_fare': estimatedFare,
        'completed_at': completedAt?.toIso8601String(),
      };

  /// Construct model from API/JSON map.
  factory DriverAssignedTrip.fromJson(Map<String, dynamic> json) {
    return DriverAssignedTrip(
      id: json['id'] as String,
      patientName: json['patient_name'] as String,
      appointmentType: json['appointment_type'] as String,
      pickupAddress: json['pickup_address'] as String,
      destination: json['destination'] as String,
      pickupTime: json['pickup_time'] as String,
      specialRequirements: List<String>.from(
        json['special_requirements'] as List? ?? [],
      ),
      status: TripAssignmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TripAssignmentStatus.assigned,
      ),
      pickupLatitude: (json['pickup_latitude'] as num?)?.toDouble(),
      pickupLongitude: (json['pickup_longitude'] as num?)?.toDouble(),
      destLatitude: (json['destination_latitude'] as num?)?.toDouble(),
      destLongitude: (json['destination_longitude'] as num?)?.toDouble(),
      estimatedFare: (json['estimated_fare'] as num?)?.toDouble(),
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
    );
  }

  // Computed getters for UI display
  bool get isActive => status == TripAssignmentStatus.assigned ||
                        status == TripAssignmentStatus.accepted ||
                        status == TripAssignmentStatus.inProgress ||
                        status == TripAssignmentStatus.arrived;
  
  bool get isCompleted => status == TripAssignmentStatus.completed;
  
  bool get isCancelled => status == TripAssignmentStatus.cancelled;
}

// ── DriverSession ─────────────────────────────────────────────────────────────

class DriverSession {
  final String uid;
  final String driverId;
  final String displayName;
  final String phone;
  final String email;
  final String memberSince;
  final VehicleType vehicleType;
  final String vehiclePlate;
  final String licenseNumber;
  final bool isOnline;
  final bool isAvailable;
  final String? currentTripId;
  final int tripsToday;
  final int totalTrips;
  final int earningsTodayTzs;
  final double rating;
  final List<DriverAssignedTrip> assignedTrips;
  final bool isLoggedIn;

  const DriverSession({
    required this.uid,
    required this.driverId,
    required this.displayName,
    required this.phone,
    required this.email,
    required this.memberSince,
    required this.vehicleType,
    required this.vehiclePlate,
    this.licenseNumber = '',
    required this.isOnline,
    required this.isAvailable,
    required this.currentTripId,
    required this.tripsToday,
    required this.totalTrips,
    required this.earningsTodayTzs,
    required this.rating,
    required this.assignedTrips,
    required this.isLoggedIn,
  });

  DriverSession copyWith({
    String? uid,
    String? driverId,
    String? displayName,
    String? phone,
    String? email,
    String? memberSince,
    VehicleType? vehicleType,
    String? vehiclePlate,
    String? licenseNumber,
    bool? isOnline,
    bool? isAvailable,
    String? currentTripId,
    int? tripsToday,
    int? totalTrips,
    int? earningsTodayTzs,
    double? rating,
    List<DriverAssignedTrip>? assignedTrips,
    bool? isLoggedIn,
  }) {
    return DriverSession(
      uid: uid ?? this.uid,
      driverId: driverId ?? this.driverId,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      memberSince: memberSince ?? this.memberSince,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      currentTripId: currentTripId ?? this.currentTripId,
      tripsToday: tripsToday ?? this.tripsToday,
      totalTrips: totalTrips ?? this.totalTrips,
      earningsTodayTzs: earningsTodayTzs ?? this.earningsTodayTzs,
      rating: rating ?? this.rating,
      assignedTrips: assignedTrips ?? this.assignedTrips,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'driver_id': driverId,
        'display_name': displayName,
        'phone': phone,
        'email': email,
        'member_since': memberSince,
        'vehicle_type': vehicleType.name,
        'vehicle_plate': vehiclePlate,
        'license_number': licenseNumber,
        'is_online': isOnline,
        'is_available': isAvailable,
        'current_trip_id': currentTripId,
        'trips_today': tripsToday,
        'total_trips': totalTrips,
        'earnings_today_tzs': earningsTodayTzs,
        'rating': rating,
        'assigned_trips': assignedTrips.map((t) => t.toJson()).toList(),
        'is_logged_in': isLoggedIn,
      };

  factory DriverSession.fromJson(Map<String, dynamic> json) {
    return DriverSession(
      uid: json['uid'] as String,
      driverId: json['driver_id'] as String? ?? '',
      displayName: json['display_name'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String? ?? '',
      memberSince: json['member_since'] as String? ?? '',
      vehicleType: VehicleType.values.firstWhere(
        (e) => e.name == json['vehicle_type'],
        orElse: () => VehicleType.standard,
      ),
      vehiclePlate: json['vehicle_plate'] as String,
      licenseNumber: json['license_number'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? false,
      currentTripId: json['current_trip_id'] as String?,
      tripsToday: json['trips_today'] as int? ?? 0,
      totalTrips: json['total_trips'] as int? ?? 0,
      earningsTodayTzs: json['earnings_today_tzs'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      assignedTrips: (json['assigned_trips'] as List<dynamic>?)
              ?.map((t) =>
                  DriverAssignedTrip.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      isLoggedIn: json['is_logged_in'] as bool? ?? false,
    );
  }

  /// Empty/unauthenticated session used as a null-safe default.
  static const empty = DriverSession(
    uid: '',
    driverId: '',
    displayName: '',
    phone: '',
    email: '',
    memberSince: '',
    vehicleType: VehicleType.standard,
    vehiclePlate: '',
    licenseNumber: '',
    isOnline: false,
    isAvailable: false,
    currentTripId: null,
    tripsToday: 0,
    totalTrips: 0,
    earningsTodayTzs: 0,
    rating: 5.0,
    assignedTrips: [],
    isLoggedIn: false,
  );

  // ── Computed Getters for UI ────────────────────────────────────────────────
  
  /// Formatted rating with 1 decimal place
  String get formattedRating => rating.toStringAsFixed(1);
  
  /// Formatted earnings for today with currency
  String get formattedEarningsToday => 'TZS $earningsTodayTzs';
  
  /// Get active trip (the one currently in progress)
  DriverAssignedTrip? get activeTrip {
    try {
      return assignedTrips.firstWhere((t) => t.isActive);
    } catch (e) {
      return null;
    }
  }
  
  /// Completed trip counts for the last 7 days (index 0 = 6 days ago, index 6 = today).
  List<int> get weeklyCompletedTripCounts {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - i));
      return completedTrips.where((t) {
        final completed = t.completedAt?.toLocal();
        if (completed == null) return false;
        return completed.year == day.year &&
            completed.month == day.month &&
            completed.day == day.day;
      }).length;
    });
  }

  /// Day-of-week labels aligned with [weeklyCompletedTripCounts] (ends today).
  List<String> get weeklyDayLabels {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - i));
      return labels[day.weekday - 1];
    });
  }

  /// Get completed trips
  List<DriverAssignedTrip> get completedTrips {
    return assignedTrips.where((t) => t.isCompleted).toList();
  }
  
  /// Get cancelled trips
  List<DriverAssignedTrip> get cancelledTrips {
    return assignedTrips.where((t) => t.isCancelled).toList();
  }
  
  /// Get recent trips (last 10)
  List<DriverAssignedTrip> get recentTrips {
    final recent = List<DriverAssignedTrip>.from(assignedTrips);
    recent.sort((a, b) => b.pickupTime.compareTo(a.pickupTime));
    return recent.take(10).toList();
  }
  
  /// Check if driver has any active trip
  bool get hasActiveTrip => activeTrip != null;
  
  /// Driver's completion rate (percentage)
  double get completionRate {
    if (totalTrips == 0) return 0.0;
    final completed = completedTrips.length;
    return (completed / totalTrips) * 100;
  }
  
  /// Formatted completion rate
  String get formattedCompletionRate => '${completionRate.toStringAsFixed(0)}%';
}
