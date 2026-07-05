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
    final token = await TripApiService.instance.getToken();
    final resp = await http.post(
      Uri.parse('$_base/trips/estimate-fare/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'pickup_latitude': pickupLat,
        'pickup_longitude': pickupLng,
        'destination_latitude': destLat,
        'destination_longitude': destLng,
        'service_type': serviceType,
        'waiting_minutes': waitingMinutes,
        if (scheduledAt != null)
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      }),
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_extractError(body));
    }
    return FareBreakdown.fromJson(body['data'] as Map<String, dynamic>);
  }

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
