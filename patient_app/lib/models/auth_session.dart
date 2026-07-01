import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSession {
  final String userId;
  final String displayName;
  final String fullName;
  final String phone;
  final String email;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final int totalTrips;
  final int tripsThisMonth;
  final String timeSaved;
  final List<dynamic> upcomingTrips;
  final List<dynamic> recentTrips;
  final int unreadNotifications;
  final bool isLoggedIn;

  const AuthSession({
    required this.userId,
    required this.displayName,
    this.fullName = '',
    required this.phone,
    required this.email,
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    required this.totalTrips,
    required this.tripsThisMonth,
    required this.timeSaved,
    required this.upcomingTrips,
    required this.recentTrips,
    required this.unreadNotifications,
    this.isLoggedIn = false,
  });

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _sessionKey = 'auth_session';

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'totalTrips': totalTrips,
      'tripsThisMonth': tripsThisMonth,
      'timeSaved': timeSaved,
      'upcomingTrips': upcomingTrips,
      'recentTrips': recentTrips,
      'unreadNotifications': unreadNotifications,
      'isLoggedIn': isLoggedIn,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      emergencyContactName: json['emergencyContactName'] as String? ?? '',
      emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
      totalTrips: json['totalTrips'] as int? ?? 0,
      tripsThisMonth: json['tripsThisMonth'] as int? ?? 0,
      timeSaved: json['timeSaved'] as String? ?? '0 hr',
      upcomingTrips: List<dynamic>.from(json['upcomingTrips'] as List? ?? const []),
      recentTrips: List<dynamic>.from(json['recentTrips'] as List? ?? const []),
      unreadNotifications: json['unreadNotifications'] as int? ?? 0,
      isLoggedIn: json['isLoggedIn'] as bool? ?? false,
    );
  }

  AuthSession copyWith({
    String? userId,
    String? displayName,
    String? fullName,
    String? phone,
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
    int? totalTrips,
    int? tripsThisMonth,
    String? timeSaved,
    List<dynamic>? upcomingTrips,
    List<dynamic>? recentTrips,
    int? unreadNotifications,
    bool? isLoggedIn,
  }) {
    return AuthSession(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      totalTrips: totalTrips ?? this.totalTrips,
      tripsThisMonth: tripsThisMonth ?? this.tripsThisMonth,
      timeSaved: timeSaved ?? this.timeSaved,
      upcomingTrips: upcomingTrips ?? this.upcomingTrips,
      recentTrips: recentTrips ?? this.recentTrips,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }

  static Future<AuthSession> load() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return signedOut();

    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return signedOut();
    }
  }

  static Future<void> save(AuthSession session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
  }

  static Future<AuthSession> addUpcomingTrip(Map<String, dynamic> trip) async {
    final session = await load();
    final updatedTrips = [trip, ...session.upcomingTrips];
    final updatedSession = session.copyWith(upcomingTrips: updatedTrips);
    await save(updatedSession);
    return updatedSession;
  }

  static AuthSession signedOut() {
    return const AuthSession(
      userId: '',
      displayName: '',
      phone: '',
      email: '',
      totalTrips: 0,
      tripsThisMonth: 0,
      timeSaved: '0 hr',
      upcomingTrips: [],
      recentTrips: [],
      unreadNotifications: 0,
      isLoggedIn: false,
    );
  }
}
