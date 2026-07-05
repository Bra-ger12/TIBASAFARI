double _toDouble(Object? v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

/// Mirrors the backend's HealthFacilitySerializer (GET /facilities/search/,
/// GET /facilities/nearby/) — a hospital/clinic/pharmacy seeded from
/// OpenStreetMap, used as a free Google-Places-API replacement for picking
/// a trip destination.
class Facility {
  final String id;
  final String name;
  final String facilityType;
  final String facilityTypeDisplay;
  final String region;
  final String district;
  final double latitude;
  final double longitude;
  final double? distanceKm;

  Facility({
    required this.id,
    required this.name,
    required this.facilityType,
    required this.facilityTypeDisplay,
    required this.region,
    required this.district,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
  });

  /// e.g. "Ilala, Dar es Salaam" — falls back gracefully when either part
  /// is missing (OSM tagging for Tanzania facilities is inconsistent).
  String get locationLabel =>
      [district, region].where((s) => s.isNotEmpty).join(', ');

  factory Facility.fromJson(Map<String, dynamic> j) => Facility(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        facilityType: j['facility_type'] as String? ?? 'HOSPITAL',
        facilityTypeDisplay: j['facility_type_display'] as String? ?? 'Hospital',
        region: j['region'] as String? ?? '',
        district: j['district'] as String? ?? '',
        latitude: _toDouble(j['latitude']),
        longitude: _toDouble(j['longitude']),
        distanceKm: j['distance_km'] == null ? null : _toDouble(j['distance_km']),
      );
}
