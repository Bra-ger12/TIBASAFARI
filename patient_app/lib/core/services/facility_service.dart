import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/models/facility.dart';

/// Talks to our own Django facility endpoints (GET /facilities/search/,
/// GET /facilities/nearby/) — a free, OSM-seeded replacement for the
/// Google Places "Select Hospital" picker, which needs billing we don't
/// have enabled.
class FacilityService {
  FacilityService._();
  static final instance = FacilityService._();

  static const String _base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tibasafari-backend.onrender.com/api/v1',
  );

  Future<List<Facility>> search({String query = '', String region = ''}) async {
    if (query.trim().isEmpty && region.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/facilities/search/').replace(
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (region.trim().isNotEmpty) 'region': region.trim(),
      },
    );
    return _fetch(uri);
  }

  Future<List<Facility>> nearby({
    required double lat,
    required double lng,
    double radiusKm = 10,
  }) {
    final uri = Uri.parse('$_base/facilities/nearby/').replace(
      queryParameters: {
        'lat': '$lat',
        'lng': '$lng',
        'radius': '$radiusKm',
      },
    );
    return _fetch(uri);
  }

  Future<List<Facility>> _fetch(Uri uri) async {
    final resp = await TripApiService.instance.sendWithAuth(
      (token) => http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_extractError(body));
    }
    final data = body['data'] as List? ?? const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Facility.fromJson)
        .toList();
  }

  String _extractError(Map<String, dynamic> body) {
    final err = body['error'];
    if (err is Map) {
      final message = err['message'];
      if (message is String) return message;
    }
    return 'Could not search facilities.';
  }
}
