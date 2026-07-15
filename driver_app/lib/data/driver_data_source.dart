import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/models/driver_notification.dart';
import '../core/models/driver_session.dart';
import '../core/models/trip_message.dart';
import '../services/auth_storage.dart';
import 'api_base_url.dart';

abstract class DriverDataSource {
  Future<DriverSession> login({
    required String email,
    required String password,
  });

  Future<void> signupDriver({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String licenseNumber,
    required String password,
    required String confirmPassword,
  });

  Future<DriverSession> fetchSession(String uid);

  Future<List<DriverAssignedTrip>> fetchAssignedTrips(String driverUid);

  Future<bool> setOnlineStatus({
    required String driverUid,
    required bool isOnline,
  });

  Future<DriverAssignedTrip> acceptTrip({
    required String driverUid,
    required String tripId,
  });

  Future<List<DriverNotification>> fetchNotifications();

  Future<DriverAssignedTrip> updateTripStatus({
    required String driverUid,
    required String tripId,
    required TripAssignmentStatus status,
  });

  Future<DriverAssignedTrip> completeTrip({
    required String tripId,
    double? distanceKm,
    int? durationMinutes,
    File? signature,
    File? proofPhoto,
  });

  Future<Map<String, dynamic>> updateUserProfile(Map<String, dynamic> fields);

  Future<Map<String, dynamic>> updateDriverProfile(Map<String, dynamic> fields);

  Future<List<Map<String, dynamic>>> fetchDriverDocuments();

  Future<Map<String, dynamic>> uploadDriverDocument({
    required String docType,
    required File file,
    String? expiryDate,
  });

  Future<int> triggerSos({
    String message = '',
    String? tripId,
    double? latitude,
    double? longitude,
  });

  Future<List<TripChatMessage>> fetchTripMessages(String tripId);

  Future<TripChatMessage> sendTripMessage({
    required String tripId,
    required String body,
  });

  Future<void> signOut();
}

class ApiDriverDataSource implements DriverDataSource {
  const ApiDriverDataSource();

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: apiBaseUrl,
  );

  static String? _accessToken;

  @override
  Future<DriverSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      '/auth/login/',
      body: {'email': email.trim(), 'password': password},
      authenticated: false,
    );
    final data = _unwrapMap(response);
    final accessToken = data['access'] as String?;
    final user = data['user'];

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Login succeeded without an access token');
    }

    if (user is Map<String, dynamic> && !_hasDriverAccess(user)) {
      throw Exception('This account is not registered as a driver');
    }

    _accessToken = accessToken;
    await AuthStorage.instance.saveTokens(
      accessToken: accessToken,
      refreshToken: data['refresh'] as String?,
      userId: user is Map<String, dynamic> ? user['id']?.toString() : null,
    );

    // Return a minimal session from the login response.
    // The home screen loads the full profile and trips separately via fetchSession().
    return _minimalSession(user is Map<String, dynamic> ? user : const {});
  }

  @override
  Future<void> signupDriver({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String licenseNumber,
    required String password,
    required String confirmPassword,
  }) async {
    await _request(
      'POST',
      '/drivers/signup/',
      body: {
        'full_name': fullName.trim(),
        'phone_number': phoneNumber.trim(),
        'email': email.trim(),
        'license_number': licenseNumber.trim(),
        'password': password,
        'confirm_password': confirmPassword,
      },
      authenticated: false,
    );
  }

  @override
  Future<DriverSession> fetchSession(String uid) async {
    // Restore token from secure storage if the in-memory copy was lost
    // (e.g. after a hot restart during development or a process resume).
    if (_accessToken == null || _accessToken!.isEmpty) {
      _accessToken = await AuthStorage.instance.getAccessToken();
    }
    _requireToken();
    return _fetchCurrentSession();
  }

  @override
  Future<void> signOut() async {
    _accessToken = null;
    await AuthStorage.instance.clear();
  }

  @override
  Future<List<DriverAssignedTrip>> fetchAssignedTrips(String driverUid) async {
    _requireToken();
    final response = await _request('GET', '/drivers/profiles/assigned-trips/');
    return _unwrapList(response).map(_tripFromJson).toList();
  }

  @override
  Future<bool> setOnlineStatus({
    required String driverUid,
    required bool isOnline,
  }) async {
    _requireToken();
    await _request(
      'PATCH',
      '/drivers/profiles/availability/',
      body: {'is_available': isOnline},
    );
    return true;
  }

  @override
  Future<DriverAssignedTrip> acceptTrip({
    required String driverUid,
    required String tripId,
  }) async {
    _requireToken();
    final response = await _request('POST', '/trips/$tripId/accept/');
    return _tripFromJson(_unwrapMap(response));
  }

  @override
  Future<List<DriverNotification>> fetchNotifications() async {
    _requireToken();
    final response = await _request('GET', '/notifications/');
    return _unwrapList(response).map(_notificationFromJson).toList();
  }

  @override
  Future<DriverAssignedTrip> updateTripStatus({
    required String driverUid,
    required String tripId,
    required TripAssignmentStatus status,
  }) async {
    _requireToken();
    final action = switch (status) {
      TripAssignmentStatus.assigned => 'reject',
      TripAssignmentStatus.accepted => 'accept',
      TripAssignmentStatus.inProgress => 'start',
      TripAssignmentStatus.arrived => 'arrive',
      TripAssignmentStatus.completed => 'complete',
      TripAssignmentStatus.cancelled => 'cancel',
    };
    final response = await _request('POST', '/trips/$tripId/$action/');
    return _tripFromJson(_unwrapMap(response));
  }

  @override
  Future<DriverAssignedTrip> completeTrip({
    required String tripId,
    double? distanceKm,
    int? durationMinutes,
    File? signature,
    File? proofPhoto,
  }) async {
    final token = _requireToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/trips/$tripId/complete/'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';
    if (distanceKm != null) {
      request.fields['distance_km'] = distanceKm.toString();
    }
    if (durationMinutes != null) {
      request.fields['duration_minutes'] = durationMinutes.toString();
    }
    if (signature != null) {
      request.files.add(await http.MultipartFile.fromPath('signature', signature.path));
    }
    if (proofPhoto != null) {
      request.files.add(await http.MultipartFile.fromPath('proof_photo', proofPhoto.path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected API response');
    }
    return _tripFromJson(_unwrapMap(decoded));
  }

  @override
  Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> fields,
  ) async {
    _requireToken();
    final response = await _request('PATCH', '/auth/profile/', body: fields);
    return _unwrapMap(response);
  }

  @override
  Future<Map<String, dynamic>> updateDriverProfile(
    Map<String, dynamic> fields,
  ) async {
    _requireToken();
    final response =
        await _request('PATCH', '/drivers/profiles/me/', body: fields);
    return _unwrapMap(response);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDriverDocuments() async {
    _requireToken();
    final response = await _request('GET', '/drivers/profiles/documents/');
    return _unwrapList(response);
  }

  @override
  Future<Map<String, dynamic>> uploadDriverDocument({
    required String docType,
    required File file,
    String? expiryDate,
  }) async {
    final token = _requireToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/drivers/profiles/documents/'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json'
      ..fields['doc_type'] = docType;
    if (expiryDate != null) request.fields['expiry_date'] = expiryDate;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected API response');
    }
    return _unwrapMap(decoded);
  }

  @override
  Future<int> triggerSos({
    String message = '',
    String? tripId,
    double? latitude,
    double? longitude,
  }) async {
    _requireToken();
    final response = await _request(
      'POST',
      '/drivers/profiles/sos/',
      body: {
        'message': message,
        'trip_id': ?tripId,
        'latitude': ?_roundCoord(latitude),
        'longitude': ?_roundCoord(longitude),
      },
    );
    final data = _unwrapMap(response);
    return (data['notified'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<TripChatMessage>> fetchTripMessages(String tripId) async {
    _requireToken();
    final response = await _request('GET', '/trips/$tripId/messages/');
    return _unwrapList(response).map(TripChatMessage.fromJson).toList();
  }

  @override
  Future<TripChatMessage> sendTripMessage({
    required String tripId,
    required String body,
  }) async {
    _requireToken();
    final response = await _request(
      'POST',
      '/trips/$tripId/messages/',
      body: {'body': body},
    );
    return TripChatMessage.fromJson(_unwrapMap(response));
  }

  /// Builds a lightweight session from the login response.
  /// Only fields available in the /auth/login/ response are populated;
  /// the rest keep their [DriverSession.empty] defaults until [fetchSession] runs.
  DriverSession _minimalSession(Map<String, dynamic> user) {
    return DriverSession.empty.copyWith(
      uid: _stringValue(user['id']) ?? '',
      displayName:
          _stringValue(user['full_name']) ??
          _nameFromEmail(_stringValue(user['email']) ?? ''),
      phone:
          _stringValue(user['phone_number']) ??
          _stringValue(user['phone']) ??
          '',
      email: _stringValue(user['email']) ?? '',
      memberSince: _yearFromDate(_stringValue(user['created_at'])),
      isLoggedIn: true,
    );
  }

  Future<DriverSession> _fetchCurrentSession() async {
    final profileResponse = await _request('GET', '/drivers/profiles/me/');
    final profile = _unwrapMap(profileResponse);

    final userResponse = await _request('GET', '/auth/profile/');
    final user = _unwrapMap(userResponse);

    final trips = await fetchAssignedTrips((user['id'] ?? '').toString());
    return _sessionFromApi(user: user, profile: profile, trips: trips);
  }

  DriverSession _sessionFromApi({
    required Map<String, dynamic> user,
    required Map<String, dynamic> profile,
    required List<DriverAssignedTrip> trips,
  }) {
    final today = DateTime.now();
    final todayPrefix = _datePrefix(today);
    final completedTrips = trips
        .where((trip) => trip.status == TripAssignmentStatus.completed)
        .toList();
    final tripsToday = trips
        .where((trip) => trip.pickupTime.startsWith(todayPrefix))
        .length;
    final earningsToday = completedTrips
        .where((trip) =>
            trip.completedAt != null &&
            _datePrefix(trip.completedAt!.toLocal()) == todayPrefix)
        .fold<double>(0, (sum, trip) => sum + (trip.fare ?? 0));

    return DriverSession(
      uid: (user['id'] ?? profile['user'] ?? '').toString(),
      driverId: (profile['id'] ?? user['id'] ?? '').toString(),
      displayName:
          _stringValue(user['full_name']) ??
          _nameFromEmail(_stringValue(user['email']) ?? ''),
      phone:
          _stringValue(user['phone_number']) ??
          _stringValue(user['phone']) ??
          '',
      email:
          _stringValue(user['email']) ??
          _stringValue(profile['user_email']) ??
          '',
      memberSince: _yearFromDate(_stringValue(user['created_at'])),
      vehicleType: _vehicleTypeFromProfile(profile),
      vehiclePlate: _stringValue(profile['vehicle_registration']) ?? '',
      licenseNumber: _stringValue(profile['license_number']) ?? '',
      isOnline: profile['is_available'] as bool? ?? false,
      isAvailable: profile['is_available'] as bool? ?? false,
      currentTripId: _currentTripId(trips),
      tripsToday: tripsToday,
      totalTrips: completedTrips.length,
      earningsTodayTzs: earningsToday.round(),
      rating: _doubleValue(profile['rating']) ?? 0,
      assignedTrips: trips,
      isLoggedIn: true,
    );
  }

  DriverAssignedTrip _tripFromJson(Map<String, dynamic> json) {
    final scheduledAt = _stringValue(json['scheduled_at']);
    final requirements = _requirementsFromJson(json['special_requirements']);
    final patientName =
        _stringValue(json['patient_name']) ??
        _stringValue(json['patient_email']) ??
        _stringValue(json['patient']) ??
        'Patient';

    return DriverAssignedTrip(
      id: (json['id'] ?? '').toString(),
      patientName: patientName,
      patientPhone: _stringValue(json['patient_phone']) ?? '',
      appointmentType:
          _stringValue(json['appointment_type']) ??
          _stringValue(json['notes']) ??
          'Medical transport',
      pickupAddress: _stringValue(json['pickup_address']) ?? '',
      destination:
          _stringValue(json['destination_address']) ??
          _stringValue(json['destination']) ??
          '',
      pickupTime: _formatPickupTime(scheduledAt),
      specialRequirements: requirements,
      status: _assignmentStatus(json['status']),
      pickupLatitude: _doubleValue(json['pickup_latitude']),
      pickupLongitude: _doubleValue(json['pickup_longitude']),
      destLatitude: _doubleValue(json['destination_latitude']),
      destLongitude: _doubleValue(json['destination_longitude']),
      estimatedFare: _doubleValue(json['estimated_fare']),
      finalFare: _doubleValue(json['final_fare']),
      completedAt: DateTime.tryParse(_stringValue(json['completed_at']) ?? ''),
    );
  }

  double? _doubleValue(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  DriverNotification _notificationFromJson(Map<String, dynamic> json) {
    return DriverNotification(
      id: (json['id'] ?? '').toString(),
      title: _stringValue(json['title']) ?? 'Notification',
      message: _stringValue(json['message']) ?? '',
      relativeTime: _relativeTime(_stringValue(json['created_at'])),
      isRead: json['is_read'] as bool? ?? false,
      type: _notificationType(json),
    );
  }

  /// The backend validates coordinates as DecimalField(decimal_places=6);
  /// GPS readings commonly carry 15+ digits of double precision, which
  /// DRF rejects outright rather than truncating.
  double? _roundCoord(double? value) =>
      value == null ? null : double.parse(value.toStringAsFixed(6));

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final encodedBody = body == null ? null : jsonEncode(body);

    Future<http.Response> attempt(String? token) {
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      return switch (method) {
        'GET' => http.get(uri, headers: headers),
        'PATCH' => http.patch(uri, headers: headers, body: encodedBody),
        'POST' => http.post(uri, headers: headers, body: encodedBody),
        _ => throw UnsupportedError('Unsupported method: $method'),
      };
    }

    var response =
        await attempt(authenticated ? _requireToken() : null);

    // The access token expires after an hour; silently refresh and retry
    // once rather than surfacing the raw JWT error to the user.
    if (authenticated && response.statusCode == 401) {
      if (await _refreshAccessToken()) {
        response = await attempt(_accessToken);
      } else {
        throw Exception('Your session has expired. Please login again.');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response));
    }
    if (response.body.isEmpty) return {};

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Unexpected API response');
  }

  /// Exchanges the stored refresh token for a new access token (the backend
  /// rotates refresh tokens too, so the new one must be saved each time).
  /// Returns false if there's no refresh token or it's itself expired/invalid.
  Future<bool> _refreshAccessToken() async {
    final refresh = await AuthStorage.instance.getRefreshToken();
    if (refresh == null) return false;
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/auth/refresh/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh': refresh}),
      );
      if (resp.statusCode != 200) {
        await AuthStorage.instance.clear();
        _accessToken = null;
        return false;
      }
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final newAccess = decoded['access'] as String?;
      if (newAccess == null) {
        await AuthStorage.instance.clear();
        _accessToken = null;
        return false;
      }
      _accessToken = newAccess;
      await AuthStorage.instance.saveTokens(
        accessToken: newAccess,
        refreshToken: decoded['refresh'] as String?,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _requireToken() {
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Please log in again');
    }
    return token;
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return _extractErrorMessage(decoded, response.statusCode);
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode})';
  }

  String _extractErrorMessage(Map<String, dynamic> decoded, int statusCode) {
    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      return _flattenError(error['message'] ?? error['detail'] ?? error);
    }
    return _flattenError(
      decoded['message'] ??
          decoded['detail'] ??
          decoded['non_field_errors'] ??
          error ??
          'Request failed ($statusCode)',
    );
  }

  String _flattenError(Object? value) {
    if (value == null) return 'Request failed';
    if (value is List) {
      return value
          .map(_flattenError)
          .where((text) => text.isNotEmpty)
          .join(', ');
    }
    if (value is Map) {
      return value.entries
          .map((entry) {
            final message = _flattenError(entry.value);
            return message.isEmpty ? '' : '${entry.key}: $message';
          })
          .where((text) => text.isNotEmpty)
          .join(', ');
    }
    return value.toString();
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) return data;
    return response;
  }

  bool _hasDriverAccess(Map<String, dynamic> user) {
    final roles = user['roles'];
    if (roles is! List) return true;

    final normalizedRoles = roles
        .map((role) => role.toString().trim().toUpperCase())
        .where((role) => role.isNotEmpty)
        .toSet();
    return normalizedRoles.contains('DRIVER') ||
        normalizedRoles.contains('ADMIN');
  }

  List<Map<String, dynamic>> _unwrapList(Map<String, dynamic> response) {
    final data = response['data'];
    final results = response['results'];
    final source = data is List
        ? data
        : results is List
        ? results
        : data is Map<String, dynamic> && data['results'] is List
        ? data['results'] as List
        : const [];
    return source.whereType<Map<String, dynamic>>().toList();
  }

  String? _stringValue(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  List<String> _requirementsFromJson(Object? value) {
    if (value == null) return const [];
    if (value is List) return value.map((item) => item.toString()).toList();
    return value
        .toString()
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  TripAssignmentStatus _assignmentStatus(Object? value) {
    final status = value?.toString().toUpperCase();
    return switch (status) {
      'ASSIGNED' => TripAssignmentStatus.assigned,
      'ACCEPTED' => TripAssignmentStatus.accepted,
      'EN_ROUTE' => TripAssignmentStatus.inProgress,
      'ARRIVED' => TripAssignmentStatus.arrived,
      'COMPLETED' => TripAssignmentStatus.completed,
      'CANCELLED' => TripAssignmentStatus.cancelled,
      _ => TripAssignmentStatus.assigned,
    };
  }

  DriverNotificationType _notificationType(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    final metadataType = metadata is Map<String, dynamic>
        ? _stringValue(metadata['type'])
        : null;
    final text =
        '${metadataType ?? ''} ${json['title'] ?? ''} ${json['message'] ?? ''}'
            .toLowerCase();

    if (text.contains('earning') || text.contains('payout')) {
      return DriverNotificationType.earnings;
    }
    if (text.contains('cancel')) return DriverNotificationType.tripCancelled;
    if (text.contains('complete')) return DriverNotificationType.tripCompleted;
    return DriverNotificationType.tripAssigned;
  }

  VehicleType _vehicleTypeFromProfile(Map<String, dynamic> profile) {
    final registration = (_stringValue(profile['vehicle_registration']) ?? '')
        .toLowerCase();
    if (registration.contains('ambulance')) return VehicleType.ambulance;
    if (registration.contains('wheelchair')) return VehicleType.wheelchair;
    return VehicleType.standard;
  }

  String _formatPickupTime(String? value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${_datePrefix(local)} $hour:$minute $period';
  }

  String _datePrefix(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _relativeTime(String? value) {
    if (value == null) return '';
    final createdAt = DateTime.tryParse(value);
    if (createdAt == null) return value;

    final delta = DateTime.now().difference(createdAt.toLocal());
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inHours < 1) return '${delta.inMinutes} min ago';
    if (delta.inDays < 1) return '${delta.inHours} hr ago';
    if (delta.inDays < 7) return '${delta.inDays} days ago';
    return _datePrefix(createdAt.toLocal());
  }

  String _yearFromDate(String? value) {
    if (value == null || value.length < 4) return '';
    return value.substring(0, 4);
  }

  String? _currentTripId(List<DriverAssignedTrip> trips) {
    for (final trip in trips) {
      if (trip.status == TripAssignmentStatus.accepted ||
          trip.status == TripAssignmentStatus.inProgress ||
          trip.status == TripAssignmentStatus.arrived) {
        return trip.id;
      }
    }
    return null;
  }

  String _nameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return 'Driver';

    return localPart
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}
