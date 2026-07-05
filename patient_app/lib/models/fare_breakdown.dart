double _toDouble(Object? v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

/// Mirrors the backend's FareBreakdownSerializer (POST /trips/estimate-fare/
/// and Trip.final_fare_breakdown). Note DRF serializes DecimalFields as JSON
/// strings (e.g. "15.98"), not numbers — _toDouble handles both.
class FareBreakdown {
  final double distanceKm;
  final double baseFare;
  final double distanceCharge;
  final int waitingMinutes;
  final double waitingCharge;
  final String serviceType;
  final double serviceMultiplier;
  final double subtotalAfterMultiplier;
  final bool isPeakHour;
  final double peakSurchargeAmount;
  final bool isUrbanZone;
  final double zoneSurchargeAmount;
  final double minimumFare;
  final double totalFare;

  FareBreakdown({
    required this.distanceKm,
    required this.baseFare,
    required this.distanceCharge,
    required this.waitingMinutes,
    required this.waitingCharge,
    required this.serviceType,
    required this.serviceMultiplier,
    required this.subtotalAfterMultiplier,
    required this.isPeakHour,
    required this.peakSurchargeAmount,
    required this.isUrbanZone,
    required this.zoneSurchargeAmount,
    required this.minimumFare,
    required this.totalFare,
  });

  factory FareBreakdown.fromJson(Map<String, dynamic> j) => FareBreakdown(
        distanceKm: _toDouble(j['distance_km']),
        baseFare: _toDouble(j['base_fare']),
        distanceCharge: _toDouble(j['distance_charge']),
        waitingMinutes: (j['waiting_minutes'] as num?)?.toInt() ?? 0,
        waitingCharge: _toDouble(j['waiting_charge']),
        serviceType: j['service_type'] as String? ?? 'basic',
        serviceMultiplier: _toDouble(j['service_multiplier']),
        subtotalAfterMultiplier: _toDouble(j['subtotal_after_multiplier']),
        isPeakHour: j['is_peak_hour'] as bool? ?? false,
        peakSurchargeAmount: _toDouble(j['peak_surcharge_amount']),
        isUrbanZone: j['is_urban_zone'] as bool? ?? false,
        zoneSurchargeAmount: _toDouble(j['zone_surcharge_amount']),
        minimumFare: _toDouble(j['minimum_fare']),
        totalFare: _toDouble(j['total_fare']),
      );

  /// For re-submitting alongside the booking request so the *shown*
  /// estimate is exactly what gets persisted as Trip.estimated_fare(_breakdown).
  Map<String, dynamic> toJson() => {
        'distance_km': distanceKm,
        'base_fare': baseFare,
        'distance_charge': distanceCharge,
        'waiting_minutes': waitingMinutes,
        'waiting_charge': waitingCharge,
        'service_type': serviceType,
        'service_multiplier': serviceMultiplier,
        'subtotal_after_multiplier': subtotalAfterMultiplier,
        'is_peak_hour': isPeakHour,
        'peak_surcharge_amount': peakSurchargeAmount,
        'is_urban_zone': isUrbanZone,
        'zone_surcharge_amount': zoneSurchargeAmount,
        'minimum_fare': minimumFare,
        'total_fare': totalFare,
      };
}
