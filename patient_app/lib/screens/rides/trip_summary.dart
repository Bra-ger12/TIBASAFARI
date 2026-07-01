enum TripStatus {
  upcoming,
  completed,
  cancelled,
}

class TripSummary {
  final String id;
  final String destination;
  final String? pickupLocation;
  final String dateLabel;
  final TripStatus status;
  final String? driverName;
  final String? driverPhone;
  final String? estimatedArrival;

  TripSummary({
    required this.id,
    required this.destination,
    this.pickupLocation,
    required this.dateLabel,
    required this.status,
    this.driverName,
    this.driverPhone,
    this.estimatedArrival,
  });
}