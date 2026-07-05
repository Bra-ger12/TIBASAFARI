import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _storage = FlutterSecureStorage();
const String _kToken = 'patient_access_token';

/// REST client for all patient-facing API calls.
class TripApiService {
  TripApiService._();
  static final instance = TripApiService._();

  // Defaults to the hosted Render backend so the app works without any
  // local setup. Override for local dev via --dart-define=API_BASE_URL=...
  static const String _base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tibasafari-backend.onrender.com/api/v1',
  );

  // ── Auth helpers ──────────────────────────────────────────────────────────

  Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);

  Future<String?> getToken() => _storage.read(key: _kToken);

  Future<void> clearToken() => _storage.delete(key: _kToken);

  // ── Patient profile ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPatientProfile() async {
    final resp = await _get('/patients/profiles/me/');
    return (resp['data'] as Map<String, dynamic>?) ?? {};
  }

  /// PATCHes emergency contact / medical fields on the patient profile
  /// (e.g. emergency_contact_name, emergency_contact_phone, medical_notes).
  Future<Map<String, dynamic>> updatePatientProfile(
      Map<String, dynamic> fields) async {
    final resp = await _patch('/patients/profiles/me/', fields);
    return (resp['data'] as Map<String, dynamic>?) ?? {};
  }

  /// GET the account-level profile (full_name, email, phone).
  Future<Map<String, dynamic>> getUserProfile() async {
    final resp = await _get('/auth/profile/');
    return (resp['data'] as Map<String, dynamic>?) ?? {};
  }

  /// PATCHes account-level fields (full_name, phone, phone_number).
  Future<Map<String, dynamic>> updateUserProfile(
      Map<String, dynamic> fields) async {
    final resp = await _patch('/auth/profile/', fields);
    return (resp['data'] as Map<String, dynamic>?) ?? {};
  }

  // ── Trips ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> bookTrip({
    required String pickupAddress,
    required String destinationAddress,
    required DateTime scheduledAt,
    String mobilityAid = 'NONE',
    String serviceLevel = 'CURB',
    bool oxygenRequired = false,
    bool medicalEscortRequired = false,
    bool ivDripRequired = false,
    bool bariatric = false,
    int numAttendants = 0,
    String specialRequirements = '',
    String notes = '',
    double? pickupLat,
    double? pickupLng,
    double? destLat,
    double? destLng,
    double? estimatedFare,
    Map<String, dynamic>? estimatedFareBreakdown,
    String? destinationFacilityId,
  }) async {
    final body = <String, dynamic>{
      'pickup_address': pickupAddress,
      'destination_address': destinationAddress,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      'mobility_aid': mobilityAid,
      'service_level': serviceLevel,
      'oxygen_required': oxygenRequired,
      'medical_escort_required': medicalEscortRequired,
      'iv_drip_required': ivDripRequired,
      'bariatric': bariatric,
      'num_attendants': numAttendants,
      'special_requirements': specialRequirements,
      'notes': notes,
      if (pickupLat != null) 'pickup_latitude': pickupLat,
      if (pickupLng != null) 'pickup_longitude': pickupLng,
      if (destLat != null) 'destination_latitude': destLat,
      if (destLng != null) 'destination_longitude': destLng,
      if (estimatedFare != null) 'estimated_fare': estimatedFare,
      if (estimatedFareBreakdown != null)
        'estimated_fare_breakdown': estimatedFareBreakdown,
      if (destinationFacilityId != null)
        'destination_facility': destinationFacilityId,
    };
    return _post('/patients/trip-requests/', body);
  }

  Future<Map<String, dynamic>> createRecurringSchedule({
    required String pickupAddress,
    required String destinationAddress,
    required String pickupTime,
    required String frequency,
    required String startDate,
    List<int> daysOfWeek = const [],
    String specialRequirements = '',
    String? endDate,
    double? pickupLat,
    double? pickupLng,
    double? destLat,
    double? destLng,
  }) async {
    final body = <String, dynamic>{
      'pickup_address': pickupAddress,
      'destination_address': destinationAddress,
      'pickup_time': pickupTime,
      'frequency': frequency,
      'start_date': startDate,
      'days_of_week': daysOfWeek,
      'special_requirements': specialRequirements,
      if (endDate != null) 'end_date': endDate,
      if (pickupLat != null) 'pickup_latitude': pickupLat,
      if (pickupLng != null) 'pickup_longitude': pickupLng,
      if (destLat != null) 'destination_latitude': destLat,
      if (destLng != null) 'destination_longitude': destLng,
    };
    return _post('/trips/recurring/', body);
  }

  /// Returns raw trip objects from the backend (all statuses).
  Future<List<dynamic>> getMyTrips() async {
    final resp = await _get('/patients/trip-requests/');
    return _extractList(resp);
  }

  /// Fetches a single trip by id, including driver_name/driver_phone/
  /// driver_vehicle_* once a driver has been assigned.
  Future<Map<String, dynamic>> getTrip(String tripId) async {
    final resp = await _get('/trips/$tripId/');
    return (resp['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> cancelTrip(String tripId) =>
      _post('/patients/trip-requests/$tripId/cancel/', {});

  Future<void> rateTrip(String tripId, int score, String comment) =>
      _post('/trips/$tripId/rate/', {'score': score, 'comment': comment});

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getNotifications() async {
    final resp = await _get('/notifications/');
    return _extractList(resp);
  }

  Future<int> getUnreadNotificationCount() async {
    try {
      final resp = await _get('/notifications/unread-count/');
      final data = resp['data'];
      if (data is Map) return (data['count'] as int?) ?? 0;
    } catch (_) {}
    return 0;
  }

  Future<void> markNotificationRead(String notifId) =>
      _post('/notifications/$notifId/mark-read/', {});

  Future<void> markAllNotificationsRead() =>
      _post('/notifications/mark-all-read/', {});

  // ── Billing ───────────────────────────────────────────────────────────────

  Future<List<dynamic>> getMyInvoices() async {
    final resp = await _get('/billing/invoices/my-invoices/');
    return _extractList(resp);
  }

  /// Self-reports a payment made outside the app (e.g. an M-Pesa transfer).
  /// Creates a PENDING payment for staff to verify — does not mark the
  /// invoice as paid immediately.
  Future<Map<String, dynamic>> submitPayment({
    required String invoiceId,
    required double amount,
    required String method,
    required String reference,
    String notes = '',
  }) async {
    final resp = await _post('/billing/invoices/$invoiceId/submit-payment/', {
      'amount': amount,
      'method': method,
      'reference': reference,
      'notes': notes,
    });
    return (resp['data'] as Map<String, dynamic>?) ?? {};
  }

  // ── Payment methods (display-only, no real gateway) ──────────────────────

  Future<List<dynamic>> getPaymentMethods() async {
    final resp = await _get('/billing/payment-methods/');
    return _extractList(resp);
  }

  /// [identifier] is the raw phone/card number — only a masked label is
  /// ever persisted server-side.
  Future<Map<String, dynamic>> addPaymentMethod({
    required String methodType,
    required String identifier,
  }) async {
    final resp = await _post('/billing/payment-methods/', {
      'method_type': methodType,
      'identifier': identifier,
    });
    return (resp['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> deletePaymentMethod(String id) =>
      _delete('/billing/payment-methods/$id/');

  Future<void> setDefaultPaymentMethod(String id) =>
      _post('/billing/payment-methods/$id/set-default/', {});

  // ── Notification preferences ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final resp = await _get('/notifications/preferences/');
    return (resp['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> updateNotificationPreferences(
      Map<String, dynamic> fields) async {
    final resp = await _patch('/notifications/preferences/', fields);
    return (resp['data'] as Map<String, dynamic>?) ?? {};
  }

  // ── Dashboard aggregation ─────────────────────────────────────────────────

  /// Fetches all trips and profile, returning a map with:
  ///   totalTrips, tripsThisMonth, upcomingTrips, recentTrips, allTrips
  /// Each trip in the lists is already mapped via [mapTripForDisplay].
  Future<Map<String, dynamic>> getPatientDashboard() async {
    final rawList = await getMyTrips();

    final now = DateTime.now();
    final upcoming = <Map<String, dynamic>>[];
    final recent = <Map<String, dynamic>>[];
    int tripsThisMonth = 0;

    for (final raw in rawList) {
      final t = raw as Map<String, dynamic>;
      final scheduledAt =
          DateTime.tryParse(t['scheduled_at'] as String? ?? '')?.toLocal();
      final statusUp = (t['status'] as String? ?? '').toUpperCase();

      if (scheduledAt != null &&
          scheduledAt.year == now.year &&
          scheduledAt.month == now.month) {
        tripsThisMonth++;
      }

      final mapped = mapTripForDisplay(t);
      if (_activeStatuses.contains(statusUp)) {
        upcoming.add(mapped);
      } else if (statusUp == 'COMPLETED' || statusUp == 'CANCELLED') {
        recent.add(mapped);
      }
    }

    // Best-effort profile fetch for the accurate trips_count from the backend.
    int totalTrips = rawList.length;
    try {
      final profile = await getPatientProfile();
      totalTrips = (profile['trips_count'] as int?) ?? totalTrips;
    } catch (_) {}

    return {
      'totalTrips': totalTrips,
      'tripsThisMonth': tripsThisMonth,
      'upcomingTrips': upcoming,
      'recentTrips': recent,
      'allTrips':
          rawList.map((t) => mapTripForDisplay(t as Map<String, dynamic>)).toList(),
    };
  }

  // ── Trip display mapping ──────────────────────────────────────────────────

  static const _activeStatuses = {
    'REQUESTED', 'ASSIGNED', 'ACCEPTED', 'EN_ROUTE', 'ARRIVED'
  };

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Maps a raw backend trip object to a display-ready map:
  ///   id, pickup, destination, date (e.g. "Jan 15 • 10:00 AM"), time, status
  static Map<String, dynamic> mapTripForDisplay(Map<String, dynamic> t) {
    final scheduledAt =
        DateTime.tryParse(t['scheduled_at'] as String? ?? '')?.toLocal();

    String dateStr = '';
    String timeStr = '';
    if (scheduledAt != null) {
      dateStr =
          '${_monthAbbr[scheduledAt.month - 1]} ${scheduledAt.day}';
      final h = scheduledAt.hour;
      final m = scheduledAt.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      timeStr = '$h12:$m $period';
    }

    final statusUp = (t['status'] as String? ?? '').toUpperCase();
    final statusDisplay = statusUp == 'COMPLETED'
        ? 'completed'
        : statusUp == 'CANCELLED'
            ? 'cancelled'
            : _activeStatuses.contains(statusUp)
                ? 'upcoming'
                : statusUp.toLowerCase();

    return {
      'id': t['id'] ?? '',
      'pickup': t['pickup_address'] ?? '',
      'destination': t['destination_address'] ?? '',
      'date': [dateStr, timeStr].where((s) => s.isNotEmpty).join(' • '),
      'time': timeStr,
      'status': statusDisplay,
      'is_rated': t['is_rated'] ?? false,
      'rating_score': t['rating_score'],
      'estimated_fare': t['estimated_fare'],
      'distance_km': t['distance_km'],
      'duration_minutes': t['duration_minutes'],
    };
  }

  // ── HTTP helpers ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final token = await getToken();
    final resp = await http.post(
      Uri.parse('$_base$path'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    return _parse(resp);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final token = await getToken();
    final resp = await http.get(
      Uri.parse('$_base$path'),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return _parse(resp);
  }

  Future<Map<String, dynamic>> _patch(
      String path, Map<String, dynamic> body) async {
    final token = await getToken();
    final resp = await http.patch(
      Uri.parse('$_base$path'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    return _parse(resp);
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final token = await getToken();
    final resp = await http.delete(
      Uri.parse('$_base$path'),
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return _parse(resp);
  }

  Map<String, dynamic> _parse(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String msg = 'Request failed (${resp.statusCode})';
      try {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final err = decoded['error'];
        if (err is Map) {
          final m = err['message'];
          if (m is String) {
            msg = m;
          } else if (m is List && m.isNotEmpty) {
            // DRF wraps a single ValidationError string in a list, e.g.
            // ["Only completed trips can be rated"] — unwrap it rather
            // than showing the raw Dart list representation.
            msg = m.first.toString();
          } else if (m != null) {
            msg = m.toString();
          }
        } else {
          msg = decoded['detail']?.toString() ?? msg;
        }
      } catch (_) {}
      throw Exception(msg);
    }
    if (resp.body.isEmpty) return {};
    final decoded = jsonDecode(resp.body);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  List<dynamic> _extractList(Map<String, dynamic> resp) {
    final data = resp['data'] ?? resp;
    if (data is List) return data;
    if (data is Map) {
      if (data['results'] is List) return data['results'] as List;
    }
    return [];
  }
}
