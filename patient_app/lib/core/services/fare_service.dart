import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/models/fare_breakdown.dart';

/// Fetches a pre-booking fare quote from POST /trips/estimate-fare/ (see
/// FareEstimator on the backend — Haversine distance, no external API).
class FareService {
  FareService._();
  static final instance = FareService._();

  static const String _base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tibasafari-backend.onrender.com/api/v1',
  );

  Future<FareBreakdown> estimateFare({
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    String serviceType = 'basic',
    int waitingMinutes = 0,
    DateTime? scheduledAt,
  }) async {
    final resp = await TripApiService.instance.sendWithAuth(
      (token) => http.post(
        Uri.parse('$_base/trips/estimate-fare/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'pickup_latitude': _roundCoord(pickupLat),
          'pickup_longitude': _roundCoord(pickupLng),
          'destination_latitude': _roundCoord(destLat),
          'destination_longitude': _roundCoord(destLng),
          'service_type': serviceType,
          'waiting_minutes': waitingMinutes,
          if (scheduledAt != null)
            'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        }),
      ),
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_extractError(body));
    }
    return FareBreakdown.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// The backend validates coordinates as DecimalField(decimal_places=6);
  /// GPS readings commonly carry 15+ digits of double precision, which
  /// DRF rejects outright rather than truncating.
  double _roundCoord(double value) => double.parse(value.toStringAsFixed(6));

  String _extractError(Map<String, dynamic> body) {
    final err = body['error'];
    if (err is Map) {
      final message = err['message'];
      if (message is String) return message;
      if (message is Map) {
        for (final entry in message.entries) {
          final val = entry.value;
          if (val is List && val.isNotEmpty) {
            return '${entry.key}: ${val.first}';
          }
        }
      }
    }
    return 'Could not calculate fare estimate.';
  }
}
