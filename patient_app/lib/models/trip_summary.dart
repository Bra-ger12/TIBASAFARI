enum TripStatus {
  completed,
  cancelled,
  upcoming,
  inProgress,
}

class TripSummary {
  final String id;
  final String destination;
  final String dateLabel;
  final TripStatus status;
  final String? driverName;

  TripSummary({
    required this.id,
    required this.destination,
    required this.dateLabel,
    required this.status,
    this.driverName,
  });
}