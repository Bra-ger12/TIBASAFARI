import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/models/auth_session.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // 10.0.2.2 is Android emulator's loopback — browsers can't reach it.
  // On web, use localhost instead.
  static const String _base = kIsWeb
      ? 'http://localhost:8000/api/v1'
      : String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:8000/api/v1',
        );

  // Backend errors: {"success": false, "error": {"code": "...", "message": <str or dict>}}
  // The message can be:
  //   - A plain string (e.g. auth errors wrapped from {"detail": "..."})
  //   - A Map with "detail" key  → {"detail": "Invalid email or password."}
  //   - A Map of field → [errors] → {"email": ["Already registered"]}
  String _extractError(Map<String, dynamic> body, String fallback) {
    final err = body['error'];
    if (err is Map) {
      final msg = err['message'];
      if (msg is String) return msg;
      if (msg is Map) {
        // DRF auth exceptions nest the detail here
        if (msg['detail'] is String) return msg['detail'] as String;
        // Field-level validation errors
        for (final key in msg.keys) {
          if (key == 'detail') continue;
          final val = msg[key];
          if (val is List && val.isNotEmpty) return '${_label(key)}: ${val.first}';
          if (val is String) return '${_label(key)}: $val';
        }
      }
    }
    if (body['detail'] != null) return body['detail'].toString();
    return fallback;
  }

  String _label(String key) {
    const map = {
      'email': 'Email',
      'password': 'Password',
      'confirm_password': 'Confirm password',
      'full_name': 'Full name',
      'phone_number': 'Phone',
      'non_field_errors': 'Error',
    };
    return map[key] ?? key;
  }

  Future<AuthSession> loginUser({
    required String email,
    required String password,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/auth/login/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email.trim().toLowerCase(), 'password': password}),
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_extractError(body, 'Login failed'));
    }

    final data = body['data'] as Map<String, dynamic>;
    await TripApiService.instance.saveToken(data['access'] as String);

    final user = data['user'] as Map<String, dynamic>;
    final fullName = user['full_name'] as String? ?? '';
    var session = AuthSession(
      userId: (user['id'] ?? '').toString(),
      displayName: fullName.split(' ').first,
      fullName: fullName,
      phone: user['phone'] as String? ?? '',
      email: user['email'] as String? ?? '',
      totalTrips: 0,
      tripsThisMonth: 0,
      timeSaved: '0 hr',
      upcomingTrips: const [],
      recentTrips: const [],
      unreadNotifications: 0,
      isLoggedIn: true,
    );
    session = await _withEmergencyContact(session);
    await AuthSession.save(session);
    return session;
  }

  /// Best-effort fetch of the patient's saved emergency contact so it shows
  /// up in the Profile screens right after login/registration.
  Future<AuthSession> _withEmergencyContact(AuthSession session) async {
    try {
      final profile = await TripApiService.instance.getPatientProfile();
      return session.copyWith(
        emergencyContactName: profile['emergency_contact_name'] as String? ?? '',
        emergencyContactPhone: profile['emergency_contact_phone'] as String? ?? '',
      );
    } catch (_) {
      return session;
    }
  }

  Future<AuthSession> registerPatient({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    String emergencyContactName = '',
    String emergencyContactPhone = '',
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/patients/signup/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'email': email.trim().toLowerCase(),
        'phone_number': phone,
        'password': password,
        'confirm_password': confirmPassword,
        'emergency_contact_name': emergencyContactName,
        'emergency_contact_phone': emergencyContactPhone,
      }),
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 201) {
      throw Exception(_extractError(body, 'Registration failed'));
    }

    final data = body['data'] as Map<String, dynamic>;
    await TripApiService.instance.saveToken(data['access'] as String);

    final user = data['user'] as Map<String, dynamic>;
    final resolvedFullName = user['full_name'] as String? ?? fullName;
    final session = AuthSession(
      userId: (user['id'] ?? '').toString(),
      displayName: resolvedFullName.split(' ').first,
      fullName: resolvedFullName,
      phone: phone,
      email: user['email'] as String? ?? email,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      totalTrips: 0,
      tripsThisMonth: 0,
      timeSaved: '0 hr',
      upcomingTrips: const [],
      recentTrips: const [],
      unreadNotifications: 0,
      isLoggedIn: true,
    );
    await AuthSession.save(session);
    return session;
  }

  Future<void> logout() async {
    await TripApiService.instance.clearToken();
    await AuthSession.clear();
  }

  Future<AuthSession?> getCurrentUser() async {
    final session = await AuthSession.load();
    return session.isLoggedIn ? session : null;
  }
}
