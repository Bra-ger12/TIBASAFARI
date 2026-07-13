import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/models/driver_notification.dart';
import '../core/models/driver_session.dart';
import '../core/models/trip_message.dart';
import '../data/driver_data_source.dart';
import 'offline_queue_service.dart';

class DriverService {
  DriverService._() : _dataSource = const ApiDriverDataSource() {
    _registerOfflineHandlers();
    OfflineQueueService.instance.startAutoRetry();
  }

  static final DriverService instance = DriverService._();

  final DriverDataSource _dataSource;

  bool _isConnectivityError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException;

  void _registerOfflineHandlers() {
    OfflineQueueService.instance.registerHandler('trip_status', (payload) async {
      try {
        await _dataSource.updateTripStatus(
          driverUid: payload['driver_uid'] as String,
          tripId: payload['trip_id'] as String,
          status: TripAssignmentStatus.values.byName(payload['status'] as String),
        );
        return true;
      } catch (e) {
        return !_isConnectivityError(e);
      }
    });
    OfflineQueueService.instance.registerHandler('sos', (payload) async {
      try {
        await _dataSource.triggerSos(
          message: payload['message'] as String? ?? '',
          tripId: payload['trip_id'] as String?,
          latitude: (payload['latitude'] as num?)?.toDouble(),
          longitude: (payload['longitude'] as num?)?.toDouble(),
        );
        return true;
      } catch (e) {
        return !_isConnectivityError(e);
      }
    });
    OfflineQueueService.instance.registerHandler('trip_message', (payload) async {
      try {
        await _dataSource.sendTripMessage(
          tripId: payload['trip_id'] as String,
          body: payload['body'] as String,
        );
        return true;
      } catch (e) {
        return !_isConnectivityError(e);
      }
    });
  }

  Future<DriverSession> login({
    required String email,
    required String password,
  }) {
    return _dataSource.login(email: email, password: password);
  }

  Future<DriverSession> loginWithGoogle({required String idToken}) {
    return _dataSource.loginWithGoogle(idToken: idToken);
  }

  Future<void> signupDriver({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String licenseNumber,
    required String password,
    required String confirmPassword,
  }) {
    return _dataSource.signupDriver(
      fullName: fullName,
      phoneNumber: phoneNumber,
      email: email,
      licenseNumber: licenseNumber,
      password: password,
      confirmPassword: confirmPassword,
    );
  }

  Future<DriverSession> fetchSession(String uid) {
    return _dataSource.fetchSession(uid);
  }

  Future<List<DriverAssignedTrip>> fetchAssignedTrips(String driverUid) {
    return _dataSource.fetchAssignedTrips(driverUid);
  }

  Future<bool> setOnlineStatus({
    required String driverUid,
    required bool isOnline,
  }) {
    return _dataSource.setOnlineStatus(
      driverUid: driverUid,
      isOnline: isOnline,
    );
  }

  Future<DriverAssignedTrip> acceptTrip({
    required String driverUid,
    required String tripId,
  }) {
    return _dataSource.acceptTrip(driverUid: driverUid, tripId: tripId);
  }

  Future<List<DriverNotification>> fetchNotifications() {
    return _dataSource.fetchNotifications();
  }

  Future<void> signOut() => _dataSource.signOut();

  Future<DriverAssignedTrip> updateTripStatus({
    required String driverUid,
    required String tripId,
    required TripAssignmentStatus status,
  }) async {
    try {
      return await _dataSource.updateTripStatus(
        driverUid: driverUid,
        tripId: tripId,
        status: status,
      );
    } catch (e) {
      if (_isConnectivityError(e)) {
        await OfflineQueueService.instance.enqueue('trip_status', {
          'driver_uid': driverUid,
          'trip_id': tripId,
          'status': status.name,
        });
        throw const ActionQueuedException();
      }
      rethrow;
    }
  }

  Future<DriverAssignedTrip> completeTrip({
    required String tripId,
    double? distanceKm,
    int? durationMinutes,
  }) {
    return _dataSource.completeTrip(
      tripId: tripId,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
    );
  }

  Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> fields,
  ) {
    return _dataSource.updateUserProfile(fields);
  }

  Future<Map<String, dynamic>> updateDriverProfile(
    Map<String, dynamic> fields,
  ) {
    return _dataSource.updateDriverProfile(fields);
  }

  Future<List<Map<String, dynamic>>> fetchDriverDocuments() {
    return _dataSource.fetchDriverDocuments();
  }

  Future<Map<String, dynamic>> uploadDriverDocument({
    required String docType,
    required File file,
    String? expiryDate,
  }) {
    return _dataSource.uploadDriverDocument(
      docType: docType,
      file: file,
      expiryDate: expiryDate,
    );
  }

  Future<int> triggerSos({
    String message = '',
    String? tripId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      return await _dataSource.triggerSos(
        message: message,
        tripId: tripId,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      if (_isConnectivityError(e)) {
        await OfflineQueueService.instance.enqueue('sos', {
          'message': message,
          'trip_id': tripId,
          'latitude': latitude,
          'longitude': longitude,
        });
        throw const ActionQueuedException();
      }
      rethrow;
    }
  }

  Future<List<TripChatMessage>> fetchTripMessages(String tripId) {
    return _dataSource.fetchTripMessages(tripId);
  }

  Future<TripChatMessage> sendTripMessage({
    required String tripId,
    required String body,
  }) async {
    try {
      return await _dataSource.sendTripMessage(tripId: tripId, body: body);
    } catch (e) {
      if (_isConnectivityError(e)) {
        await OfflineQueueService.instance.enqueue('trip_message', {
          'trip_id': tripId,
          'body': body,
        });
        throw const ActionQueuedException();
      }
      rethrow;
    }
  }
}
