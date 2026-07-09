import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:patient_app/core/services/notifications_ws_service.dart';
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/models/auth_session.dart';

/// Thrown by [AuthService.loginUser] when the backend rejects login with
/// `error.code == "email_not_verified"` — lets the login screen offer a
/// "Verify now" action instead of a plain error message.
class EmailNotVerifiedException implements Exception {
  final String email;
  final String message;
  EmailNotVerifiedException(this.email, this.message);

  @override
  String toString() => message;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Defaults to the hosted Render backend so the app works without any
  // local setup. Override for local dev via --dart-define=API_BASE_URL=...
  // (e.g. http://10.0.2.2:8000/api/v1 for an Android emulator).
  static const String _base = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tibasafari-backend.onrender.com/api/v1',
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
      final err = body['error'];
      if (err is Map && err['code'] == 'email_not_verified') {
        throw EmailNotVerifiedException(
          email.trim().toLowerCase(),
          _extractError(body, 'Please verify your email before logging in'),
        );
      }
      throw Exception(_extractError(body, 'Login failed'));
    }
    return _sessionFromAuthData(body['data'] as Map<String, dynamic>);
  }

  /// Exchanges a Google ID token (obtained client-side via google_sign_in)
  /// for a Tiba Safari session — signs in if the email already has an
  /// account, otherwise silently registers a new patient.
  Future<AuthSession> loginWithGoogle({required String idToken}) async {
    final resp = await http.post(
      Uri.parse('$_base/patients/auth/google/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_extractError(body, 'Google sign-in failed'));
    }
    return _sessionFromAuthData(body['data'] as Map<String, dynamic>);
  }

  /// Exchanges an Apple identity token (obtained client-side via
  /// sign_in_with_apple) for a Tiba Safari session. [fullName] should be
  /// passed on the very first sign-in only — Apple never includes it in
  /// the token itself, only in a one-time client-side payload.
  Future<AuthSession> loginWithApple({
    required String idToken,
    String? fullName,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/patients/auth/apple/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'id_token': idToken,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      }),
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_extractError(body, 'Apple sign-in failed'));
    }
    return _sessionFromAuthData(body['data'] as Map<String, dynamic>);
  }

  Future<AuthSession> _sessionFromAuthData(Map<String, dynamic> data) async {
    await TripApiService.instance.saveToken(data['access'] as String);
    final refresh = data['refresh'] as String?;
    if (refresh != null) {
      await TripApiService.instance.saveRefreshToken(refresh);
    }

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

  /// Creates the account and sends a verification code — the account has
  /// no usable session until [verifyEmail] succeeds, so no tokens are
  /// returned here; the caller should navigate to the verify-email screen.
  Future<void> registerPatient({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
    String emergencyContactName = '',
    String emergencyContactPhone = '',
    String mobilityNeeds = 'NONE',
    bool oxygenRequired = false,
    bool medicalEscortRequired = false,
    bool ivDripRequired = false,
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
        'mobility_needs': mobilityNeeds,
        'oxygen_required': oxygenRequired,
        'medical_escort_required': medicalEscortRequired,
        'iv_drip_required': ivDripRequired,
      }),
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 201) {
      throw Exception(_extractError(body, 'Registration failed'));
    }
  }

  Future<void> verifyEmail({required String email, required String code}) async {
    final resp = await http.post(
      Uri.parse('$_base/auth/verify-email/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email.trim().toLowerCase(), 'code': code.trim()}),
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_extractError(body, 'Verification failed'));
    }
  }

  Future<void> resendVerification({required String email}) async {
    final resp = await http.post(
      Uri.parse('$_base/auth/resend-verification/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_extractError(body, 'Could not resend code'));
    }
  }

  Future<void> requestPasswordReset({required String email}) async {
    final resp = await http.post(
      Uri.parse('$_base/auth/password-reset/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email.trim().toLowerCase()}),
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_extractError(body, 'Could not request password reset'));
    }
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final resp = await http.post(
      Uri.parse('$_base/auth/password-reset/confirm/'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'new_password': newPassword,
      }),
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw Exception(_extractError(body, 'Password reset failed'));
    }
  }

  Future<void> logout() async {
    NotificationsWsService.instance.disconnect();
    await TripApiService.instance.clearToken();
    await AuthSession.clear();
  }

  Future<AuthSession?> getCurrentUser() async {
    final session = await AuthSession.load();
    return session.isLoggedIn ? session : null;
  }
}
