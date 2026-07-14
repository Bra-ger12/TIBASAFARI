// Domain models matching the Tiba Safari Django REST API response shapes.
// All fromJson methods accept snake_case keys (Django convention) with
// camelCase fallbacks for backwards compatibility.

class Driver {
  final String id;
  /// User.id — the account id backend `/assign-driver/` expects, distinct
  /// from `id` (the DriverProfile primary key).
  final String userId;
  final String name;
  final String email;
  final String phone;
  final String licenseNumber;
  /// online | offline | on_trip  (derived from is_available + trip status)
  final String status;
  final double rating;
  final int tripsCount;
  final String avatarColor;
  final String? vehicleId;
  final String? vehiclePlate;
  final Vehicle? vehicle;
  final List<DriverDocument> documents;

  Driver({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.licenseNumber,
    required this.status,
    required this.rating,
    required this.tripsCount,
    required this.avatarColor,
    this.vehicleId,
    this.vehiclePlate,
    this.vehicle,
    this.documents = const [],
  });

  factory Driver.fromJson(Map<String, dynamic> j) {
    // DriverProfileSerializer returns: user_full_name, user_email, user_phone,
    // license_number, is_available, vehicle (UUID), vehicle_registration, trips_count.
    final isAvailable = j['is_available'] as bool? ?? true;
    return Driver(
      id: (j['id'] ?? '').toString(),
      userId: (j['user'] ?? j['userId'] ?? j['id'] ?? '').toString(),
      name: j['user_full_name'] as String? ??
          j['name'] as String? ??
          j['user_email'] as String? ??
          '',
      email: j['user_email'] as String? ?? j['email'] as String? ?? '',
      phone: j['user_phone'] as String? ?? j['phone'] as String? ?? '',
      licenseNumber: j['license_number'] as String? ??
          j['licenseNumber'] as String? ??
          '',
      status: j['status'] as String? ?? (isAvailable ? 'online' : 'offline'),
      rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
      tripsCount: (j['trips_count'] as num?)?.toInt() ??
          (j['tripsCount'] as num?)?.toInt() ??
          0,
      avatarColor: j['avatar_color'] as String? ??
          j['avatarColor'] as String? ??
          'emerald',
      vehicleId: (j['vehicle'] ?? j['vehicleId'])?.toString(),
      vehiclePlate: j['vehicle_registration'] as String? ??
          j['vehiclePlate'] as String?,
      vehicle: j['vehicle'] is Map<String, dynamic>
          ? Vehicle.fromJson(j['vehicle'] as Map<String, dynamic>)
          : (j['vehicle'] != null && j['vehicle'].toString().isNotEmpty)
              // Backend only sends the vehicle as a bare UUID + a flat
              // vehicle_registration string here, not a nested object —
              // build a minimal Vehicle so the assigned car still shows.
              ? Vehicle(
                  id: j['vehicle'].toString(),
                  plate: j['vehicle_registration'] as String? ?? '',
                  model: '',
                  make: '',
                  year: 0,
                  type: 'ambulance',
                  capacity: 4,
                  status: 'available',
                )
              : null,
      documents: (j['documents'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(DriverDocument.fromJson)
              .toList() ??
          const [],
    );
  }
}

class DriverDocument {
  final String id;
  final String docType;
  final String docTypeDisplay;
  final String? fileUrl;
  final String status;
  final String rejectionReason;
  final String? uploadedAt;

  DriverDocument({
    required this.id,
    required this.docType,
    required this.docTypeDisplay,
    required this.status,
    required this.rejectionReason,
    this.fileUrl,
    this.uploadedAt,
  });

  factory DriverDocument.fromJson(Map<String, dynamic> j) {
    return DriverDocument(
      id: (j['id'] ?? '').toString(),
      docType: j['doc_type'] as String? ?? '',
      docTypeDisplay: j['doc_type_display'] as String? ?? '',
      fileUrl: j['file'] as String?,
      status: j['status'] as String? ?? 'PENDING',
      rejectionReason: j['rejection_reason'] as String? ?? '',
      uploadedAt: j['uploaded_at'] as String?,
    );
  }
}

class Vehicle {
  final String id;
  final String plate;
  final String model;
  final String make;
  final int year;
  final String type;
  final int capacity;
  final bool hasWheelchairAccess;
  final String status;
  final Driver? driver;

  Vehicle({
    required this.id,
    required this.plate,
    required this.model,
    required this.make,
    required this.year,
    required this.type,
    required this.capacity,
    this.hasWheelchairAccess = false,
    required this.status,
    this.driver,
  });

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: (j['id'] ?? '').toString(),
        plate: j['registration_number'] as String? ??
            j['plate'] as String? ??
            '',
        model: j['model'] as String? ?? '',
        make: j['make'] as String? ?? '',
        year: (j['year'] as num?)?.toInt() ?? 0,
        type: (j['has_wheelchair_access'] as bool? ?? false)
            ? 'wheelchair-van'
            : (j['type'] as String? ?? j['vehicle_type'] as String? ?? 'ambulance'),
        capacity: (j['capacity'] as num?)?.toInt() ?? 4,
        hasWheelchairAccess: j['has_wheelchair_access'] as bool? ?? false,
        status: j['status'] as String? ?? 'available',
        driver: j['driver'] is Map<String, dynamic>
            ? Driver.fromJson(j['driver'] as Map<String, dynamic>)
            : null,
      );
}

class VehicleExpense {
  final String id;
  final String vehicleId;
  final String vehicleRegistration;
  final String category;
  final String description;
  final double amount;
  final String incurredAt;

  VehicleExpense({
    required this.id,
    required this.vehicleId,
    required this.vehicleRegistration,
    required this.category,
    required this.description,
    required this.amount,
    required this.incurredAt,
  });

  factory VehicleExpense.fromJson(Map<String, dynamic> j) => VehicleExpense(
        id: (j['id'] ?? '').toString(),
        vehicleId: (j['vehicle'] ?? '').toString(),
        vehicleRegistration: j['vehicle_registration'] as String? ?? '',
        category: j['category'] as String? ?? 'MAINTENANCE',
        description: j['description'] as String? ?? '',
        amount: _toDouble(j['amount'] ?? 0),
        incurredAt: j['incurred_at'] as String? ?? '',
      );
}

class Patient {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? gender;
  final String? address;
  final bool active;
  final String? mobilityNeeds;
  final List<String>? specialNeeds;
  final String? medicalNotes;
  final bool oxygenRequired;
  final bool medicalEscortRequired;
  final bool ivDripRequired;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final int tripsCount;
  final String createdAt;
  final List<PatientDocument> documents;

  Patient({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.gender,
    this.address,
    required this.active,
    this.mobilityNeeds,
    this.specialNeeds,
    this.medicalNotes,
    this.oxygenRequired = false,
    this.medicalEscortRequired = false,
    this.ivDripRequired = false,
    this.emergencyContactName,
    this.emergencyContactPhone,
    required this.tripsCount,
    required this.createdAt,
    this.documents = const [],
  });

  factory Patient.fromJson(Map<String, dynamic> j) {
    final needs = _parseNeeds(
        j['special_needs'] ?? j['specialNeeds'] ??
        j['mobility_needs'] ?? j['mobilityNeeds']);
    return Patient(
      id: (j['id'] ?? '').toString(),
      name: j['user_full_name'] as String? ??
          j['name'] as String? ??
          j['user_email'] as String? ??
          '',
      phone: j['user_phone'] as String? ?? j['phone'] as String? ?? '',
      email: j['user_email'] as String? ?? j['email'] as String?,
      gender: j['gender'] as String?,
      address: j['default_pickup_address'] as String? ??
          j['address'] as String?,
      active: j['active'] as bool? ?? j['is_active'] as bool? ?? true,
      mobilityNeeds: j['mobility_needs'] as String? ??
          j['mobilityNeeds'] as String?,
      specialNeeds: needs,
      medicalNotes: j['medical_notes'] as String? ??
          j['medicalNotes'] as String?,
      oxygenRequired: j['oxygen_required'] as bool? ?? false,
      medicalEscortRequired: j['medical_escort_required'] as bool? ?? false,
      ivDripRequired: j['iv_drip_required'] as bool? ?? false,
      emergencyContactName: j['emergency_contact_name'] as String? ??
          j['emergencyContactName'] as String?,
      emergencyContactPhone: j['emergency_contact_phone'] as String? ??
          j['emergencyContactPhone'] as String?,
      tripsCount: (j['trips_count'] as num?)?.toInt() ??
          (j['tripsCount'] as num?)?.toInt() ??
          0,
      createdAt: j['created_at'] as String? ?? j['createdAt'] as String? ?? '',
      documents: (j['documents'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(PatientDocument.fromJson)
              .toList() ??
          const [],
    );
  }
}

class PatientDocument {
  final String id;
  final String docType;
  final String docTypeDisplay;
  final String? fileUrl;
  final String description;
  final String? uploadedAt;

  PatientDocument({
    required this.id,
    required this.docType,
    required this.docTypeDisplay,
    this.fileUrl,
    required this.description,
    this.uploadedAt,
  });

  factory PatientDocument.fromJson(Map<String, dynamic> j) {
    return PatientDocument(
      id: (j['id'] ?? '').toString(),
      docType: j['doc_type'] as String? ?? '',
      docTypeDisplay: j['doc_type_display'] as String? ?? '',
      fileUrl: j['file'] as String?,
      description: j['description'] as String? ?? '',
      uploadedAt: j['uploaded_at'] as String?,
    );
  }
}

/// A trip request/booking. In the Django backend, "bookings" are trips
/// with status REQUESTED; all trips live at /api/v1/trips/.
class Booking {
  final String id;
  final String reference;
  final String patientId;
  final Patient? patient;
  final String patientName;
  final String pickup;
  final String dropoff;
  final double pickupLat;
  final double pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final String scheduledAt;
  final String status;
  final String? specialRequirements;
  final List<String>? specialNeeds;
  final Trip? trip;
  final String? notes;
  final double fare;
  final String? driverId;
  final Driver? driver;
  final String driverName;
  final String createdAt;

  Booking({
    required this.id,
    required this.reference,
    required this.patientId,
    this.patient,
    required this.patientName,
    required this.pickup,
    required this.dropoff,
    required this.pickupLat,
    required this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    required this.scheduledAt,
    required this.status,
    this.specialRequirements,
    this.specialNeeds,
    this.trip,
    this.notes,
    required this.fare,
    this.driverId,
    this.driver,
    this.driverName = '',
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: (j['id'] ?? '').toString(),
        reference: j['reference'] as String? ??
            (j['id'] ?? '').toString().substring(0, 8).toUpperCase(),
        patientId: (j['patient'] ?? j['patientId'] ?? '').toString(),
        patient: j['patient'] is Map<String, dynamic>
            ? Patient.fromJson(j['patient'] as Map<String, dynamic>)
            : null,
        patientName: j['patient_name'] as String? ??
            j['patientName'] as String? ??
            '',
        pickup: j['pickup_address'] as String? ??
            j['pickup'] as String? ??
            '',
        dropoff: j['destination_address'] as String? ??
            j['dropoff'] as String? ??
            '',
        pickupLat: _toDouble(
            j['pickup_latitude'] ?? j['pickupLat'] ?? j['pickup_lat']),
        pickupLng: _toDouble(
            j['pickup_longitude'] ?? j['pickupLng'] ?? j['pickup_lng']),
        dropoffLat: _toDoubleOpt(
            j['destination_latitude'] ?? j['dropoffLat'] ?? j['dropoff_lat']),
        dropoffLng: _toDoubleOpt(
            j['destination_longitude'] ?? j['dropoffLng'] ?? j['dropoff_lng']),
        scheduledAt: j['scheduled_at'] as String? ??
            j['scheduledAt'] as String? ??
            '',
        status: j['status'] as String? ?? 'REQUESTED',
        specialRequirements: j['special_requirements'] as String? ??
            j['specialRequirements'] as String?,
        specialNeeds: _parseNeeds(
            j['special_needs'] ?? j['specialNeeds'] ?? j['special_requirements']),
        trip: j['trip'] is Map<String, dynamic>
            ? Trip.fromJson(j['trip'] as Map<String, dynamic>)
            : null,
        notes: j['notes'] as String?,
        fare: _toDouble(j['estimated_fare'] ?? j['fare'] ?? 0),
        driverId: (j['driver'] is String ? j['driver'] : j['driverId'])
            ?.toString(),
        driver: j['driver'] is Map<String, dynamic>
            ? Driver.fromJson(j['driver'] as Map<String, dynamic>)
            : null,
        driverName: j['driver_name'] as String? ??
            j['driverName'] as String? ??
            '',
        createdAt: j['created_at'] as String? ??
            j['createdAt'] as String? ??
            '',
      );
}

class Trip {
  final String id;
  final String reference;
  final String patientId;
  final Patient? patient;
  final String patientName;
  final String patientEmail;
  final String driverId;
  final Driver? driver;
  final String driverName;
  final String driverEmail;
  final String vehicleId;
  final Vehicle? vehicle;
  final String pickup;
  final String dropoff;
  final double pickupLat;
  final double pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final String status;
  final double fare;
  final double distanceKm;
  final String scheduledAt;
  final String? startedAt;
  final String? endedAt;
  final double? currentLat;
  final double? currentLng;
  final String? mobilityAid;
  final String? serviceLevel;
  final String createdAt;

  Trip({
    required this.id,
    required this.reference,
    required this.patientId,
    this.patient,
    required this.patientName,
    this.patientEmail = '',
    required this.driverId,
    this.driver,
    required this.driverName,
    this.driverEmail = '',
    required this.vehicleId,
    this.vehicle,
    required this.pickup,
    required this.dropoff,
    required this.pickupLat,
    required this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    required this.status,
    required this.fare,
    required this.distanceKm,
    required this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.currentLat,
    this.currentLng,
    this.mobilityAid,
    this.serviceLevel,
    required this.createdAt,
  });

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: (j['id'] ?? '').toString(),
        reference: j['reference'] as String? ??
            (j['id'] ?? '').toString().substring(0, 8).toUpperCase(),
        patientId: (j['patient'] is String
                ? j['patient']
                : j['patientId'] ?? '')
            .toString(),
        patient: j['patient'] is Map<String, dynamic>
            ? Patient.fromJson(j['patient'] as Map<String, dynamic>)
            : null,
        patientName: j['patient_name'] as String? ??
            j['patientName'] as String? ??
            j['patient_email'] as String? ??
            '',
        patientEmail: j['patient_email'] as String? ??
            j['patientEmail'] as String? ??
            '',
        driverId: (j['driver'] is String
                ? j['driver']
                : j['driverId'] ?? '')
            .toString(),
        driver: j['driver'] is Map<String, dynamic>
            ? Driver.fromJson(j['driver'] as Map<String, dynamic>)
            : null,
        driverName: j['driver_name'] as String? ??
            j['driverName'] as String? ??
            j['driver_email'] as String? ??
            '',
        driverEmail: j['driver_email'] as String? ??
            j['driverEmail'] as String? ??
            '',
        vehicleId: (j['vehicle'] is String
                ? j['vehicle']
                : j['vehicleId'] ?? '')
            .toString(),
        vehicle: j['vehicle'] is Map<String, dynamic>
            ? Vehicle.fromJson(j['vehicle'] as Map<String, dynamic>)
            : null,
        pickup: j['pickup_address'] as String? ??
            j['pickup'] as String? ??
            '',
        dropoff: j['destination_address'] as String? ??
            j['dropoff'] as String? ??
            '',
        pickupLat: _toDouble(
            j['pickup_latitude'] ?? j['pickupLat'] ?? j['pickup_lat']),
        pickupLng: _toDouble(
            j['pickup_longitude'] ?? j['pickupLng'] ?? j['pickup_lng']),
        dropoffLat: _toDoubleOpt(
            j['destination_latitude'] ?? j['dropoffLat'] ?? j['dropoff_lat']),
        dropoffLng: _toDoubleOpt(
            j['destination_longitude'] ?? j['dropoffLng'] ?? j['dropoff_lng']),
        status: j['status'] as String? ?? '',
        fare: _toDouble(j['estimated_fare'] ?? j['fare'] ?? 0),
        distanceKm: _toDouble(j['distance_km'] ?? j['distanceKm'] ?? 0),
        scheduledAt: j['scheduled_at'] as String? ??
            j['scheduledAt'] as String? ??
            '',
        startedAt: j['started_at'] as String? ?? j['startedAt'] as String?,
        endedAt: j['ended_at'] as String? ?? j['endedAt'] as String?,
        currentLat: _toDoubleOpt(j['current_lat'] ?? j['currentLat']),
        currentLng: _toDoubleOpt(j['current_lng'] ?? j['currentLng']),
        mobilityAid: j['mobility_aid'] as String? ??
            j['mobilityAid'] as String?,
        serviceLevel: j['service_level'] as String? ??
            j['serviceLevel'] as String?,
        createdAt: j['created_at'] as String? ??
            j['createdAt'] as String? ??
            '',
      );
}

class InvoiceLine {
  final String label;
  final double amount;

  InvoiceLine({required this.label, required this.amount});

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
        label: j['label'] as String? ?? j['description'] as String? ?? '',
        amount: _toDouble(j['amount'] ?? 0),
      );
}

class Invoice {
  final String id;
  final String number;
  final String? tripId;
  final String patientId;
  final Patient? patient;
  final double amount;
  final double amountPaid;
  final double amountDue;
  final String status;
  final String dueDate;
  final String issuedAt;
  final String? paidAt;
  final List<InvoiceLine> breakdown;
  final String createdAt;

  Invoice({
    required this.id,
    required this.number,
    this.tripId,
    required this.patientId,
    this.patient,
    required this.amount,
    required this.amountPaid,
    required this.amountDue,
    required this.status,
    required this.dueDate,
    required this.issuedAt,
    this.paidAt,
    required this.breakdown,
    required this.createdAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        id: (j['id'] ?? '').toString(),
        number: j['invoice_number'] as String? ??
            j['number'] as String? ??
            (j['id'] ?? '').toString().substring(0, 8).toUpperCase(),
        tripId: (j['trip'] is String ? j['trip'] : j['tripId'])?.toString(),
        patientId: (j['patient'] is String
                ? j['patient']
                : j['patientId'] ?? '')
            .toString(),
        patient: j['patient'] is Map<String, dynamic>
            ? Patient.fromJson(j['patient'] as Map<String, dynamic>)
            : null,
        amount: _toDouble(j['total_amount'] ?? j['amount'] ?? 0),
        amountPaid: _toDouble(j['amount_paid'] ?? j['amountPaid'] ?? 0),
        amountDue: _toDouble(j['amount_due'] ?? j['amountDue'] ?? 0),
        status: (j['status'] as String? ?? 'DRAFT').toLowerCase(),
        dueDate: j['due_date'] as String? ?? j['dueDate'] as String? ?? '',
        issuedAt: j['issued_at'] as String? ??
            j['issuedAt'] as String? ??
            j['created_at'] as String? ??
            '',
        paidAt: j['paid_at'] as String? ?? j['paidAt'] as String?,
        breakdown: j['breakdown'] is List
            ? (j['breakdown'] as List)
                .whereType<Map<String, dynamic>>()
                .map(InvoiceLine.fromJson)
                .toList()
            : [],
        createdAt: j['created_at'] as String? ??
            j['createdAt'] as String? ??
            '',
      );
}

class NotificationRecord {
  final String id;
  final String title;
  final String message;
  final String audience;
  final String channel;
  final String sentAt;
  final int recipients;

  NotificationRecord({
    required this.id,
    required this.title,
    required this.message,
    required this.audience,
    required this.channel,
    required this.sentAt,
    required this.recipients,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> j) =>
      NotificationRecord(
        id: (j['id'] ?? '').toString(),
        title: j['title'] as String? ?? '',
        message: j['message'] as String? ?? j['body'] as String? ?? '',
        audience: j['audience'] as String? ??
            j['recipient_type'] as String? ??
            'all',
        channel: j['channel'] as String? ?? 'push',
        sentAt: j['sent_at'] as String? ??
            j['sentAt'] as String? ??
            j['created_at'] as String? ??
            '',
        recipients: (j['recipients'] as num?)?.toInt() ??
            (j['recipient_count'] as num?)?.toInt() ??
            0,
      );
}

class DashboardKpi {
  final int activeTrips;
  final int pendingBookings;
  final int driversOnline;
  final double revenueToday;
  // Null (not 0) when there's no real day-over-day figure to compare —
  // the "vs yesterday" badge only renders when this is non-null, so a
  // stat with no trend data simply shows no badge rather than a fake 0%.
  final int? activeTripsTrend;
  final int? pendingBookingsTrend;
  final int? driversOnlineTrend;
  final int? revenueTrend;

  DashboardKpi({
    required this.activeTrips,
    required this.pendingBookings,
    required this.driversOnline,
    required this.revenueToday,
    this.activeTripsTrend,
    this.pendingBookingsTrend,
    this.driversOnlineTrend,
    this.revenueTrend,
  });

  /// Parses from the Django `/dashboard/stats/` response shape:
  /// `{ trips: {active, requested, ...}, drivers: {available, total}, revenue: {today, yesterday, trend_pct} }`
  factory DashboardKpi.fromStats(Map<String, dynamic> stats) {
    final trips = stats['trips'] as Map<String, dynamic>? ?? {};
    final drivers = stats['drivers'] as Map<String, dynamic>? ?? {};
    final revenue = stats['revenue'] as Map<String, dynamic>? ?? {};
    return DashboardKpi(
      activeTrips: (trips['active'] as num?)?.toInt() ?? 0,
      pendingBookings: (trips['requested'] as num?)?.toInt() ?? 0,
      driversOnline: (drivers['available'] as num?)?.toInt() ?? 0,
      revenueToday: _toDouble(revenue['today'] ?? 0),
      revenueTrend: (revenue['trend_pct'] as num?)?.round() ?? 0,
    );
  }

  factory DashboardKpi.fromJson(Map<String, dynamic> j) => DashboardKpi(
        activeTrips: (j['active_trips'] as num?)?.toInt() ??
            (j['activeTrips'] as num?)?.toInt() ??
            0,
        pendingBookings: (j['pending_bookings'] as num?)?.toInt() ??
            (j['pendingBookings'] as num?)?.toInt() ??
            0,
        driversOnline: (j['drivers_online'] as num?)?.toInt() ??
            (j['driversOnline'] as num?)?.toInt() ??
            0,
        revenueToday: _toDouble(
            j['revenue_today'] ?? j['revenueToday'] ?? 0),
        activeTripsTrend: (j['active_trips_trend'] as num?)?.toInt() ??
            (j['activeTripsTrend'] as num?)?.toInt() ??
            0,
        pendingBookingsTrend:
            (j['pending_bookings_trend'] as num?)?.toInt() ??
                (j['pendingBookingsTrend'] as num?)?.toInt() ??
                0,
        driversOnlineTrend: (j['drivers_online_trend'] as num?)?.toInt() ??
            (j['driversOnlineTrend'] as num?)?.toInt() ??
            0,
        revenueTrend: (j['revenue_trend'] as num?)?.toInt() ??
            (j['revenueTrend'] as num?)?.toInt() ??
            0,
      );
}

class ActiveTripMapItem {
  final String id;
  final String reference;
  final String? driverId;
  /// Pickup coordinates — fixed for the life of the trip.
  final double lat;
  final double lng;
  /// The driver's live position, if a driver_location event has arrived
  /// yet over the dispatch WebSocket; null falls back to the pickup point.
  final double? vehicleLat;
  final double? vehicleLng;
  final String driverName;
  final String patientName;
  final String pickup;
  final String dropoff;
  final String status;
  final String vehiclePlate;

  ActiveTripMapItem({
    required this.id,
    required this.reference,
    this.driverId,
    required this.lat,
    required this.lng,
    this.vehicleLat,
    this.vehicleLng,
    required this.driverName,
    required this.patientName,
    required this.pickup,
    required this.dropoff,
    required this.status,
    required this.vehiclePlate,
  });

  factory ActiveTripMapItem.fromJson(Map<String, dynamic> j) =>
      ActiveTripMapItem(
        id: (j['id'] ?? '').toString(),
        reference: j['reference'] as String? ??
            (j['id'] ?? '').toString().substring(0, 8).toUpperCase(),
        driverId: (j['driver'] ?? j['driver_id'])?.toString(),
        lat: _toDouble(j['pickup_latitude'] ?? j['lat'] ?? 0),
        lng: _toDouble(j['pickup_longitude'] ?? j['lng'] ?? 0),
        driverName: j['driver_name'] as String? ??
            j['driverName'] as String? ??
            j['driver_email'] as String? ??
            '',
        patientName: j['patient_name'] as String? ??
            j['patientName'] as String? ??
            j['patient_email'] as String? ??
            '',
        pickup: j['pickup_address'] as String? ?? j['pickup'] as String? ?? '',
        dropoff: j['destination_address'] as String? ??
            j['dropoff'] as String? ??
            '',
        status: j['status'] as String? ?? '',
        vehiclePlate: j['vehicle_plate'] as String? ??
            j['vehiclePlate'] as String? ??
            '',
      );

  ActiveTripMapItem copyWith({
    double? vehicleLat,
    double? vehicleLng,
    String? status,
  }) =>
      ActiveTripMapItem(
        id: id,
        reference: reference,
        driverId: driverId,
        lat: lat,
        lng: lng,
        vehicleLat: vehicleLat ?? this.vehicleLat,
        vehicleLng: vehicleLng ?? this.vehicleLng,
        driverName: driverName,
        patientName: patientName,
        pickup: pickup,
        dropoff: dropoff,
        status: status ?? this.status,
        vehiclePlate: vehiclePlate,
      );
}

class AdminUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phone;

  AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: (j['id'] ?? '').toString(),
        name: j['full_name'] as String? ??
            j['name'] as String? ??
            j['email'] as String? ??
            '',
        email: j['email'] as String? ?? '',
        role: j['roles'] is List && (j['roles'] as List).isNotEmpty
            ? (j['roles'] as List).first.toString()
            : j['role'] as String? ?? 'admin',
        phone: j['phone'] as String? ?? j['phone_number'] as String?,
      );
}

// ── Helpers ─────────────────────────────────────────────────────────────────

List<String>? _parseNeeds(dynamic v) {
  if (v == null) return null;
  if (v is List) {
    final r = v.whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return r.isEmpty ? null : r;
  }
  if (v is String && v.isNotEmpty) {
    final r = v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return r.isEmpty ? null : r;
  }
  return null;
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

double? _toDoubleOpt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
