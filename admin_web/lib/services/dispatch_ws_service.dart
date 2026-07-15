import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth_storage.dart';

class TripUpdateEvent {
  final String tripId;
  final String status;
  final String? driverId;
  final double? pickupLat;
  final double? pickupLng;

  const TripUpdateEvent({
    required this.tripId,
    required this.status,
    this.driverId,
    this.pickupLat,
    this.pickupLng,
  });

  factory TripUpdateEvent.fromJson(Map<String, dynamic> json) {
    return TripUpdateEvent(
      tripId: (json['trip_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      driverId: json['driver_id']?.toString(),
      pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
    );
  }
}

class DriverLocationEvent {
  final String driverId;
  final String? tripId;
  final double lat;
  final double lng;

  const DriverLocationEvent({
    required this.driverId,
    this.tripId,
    required this.lat,
    required this.lng,
  });

  factory DriverLocationEvent.fromJson(Map<String, dynamic> json) {
    return DriverLocationEvent(
      driverId: (json['driver_id'] ?? '').toString(),
      tripId: json['trip_id']?.toString(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

/// Dispatch-wide WebSocket feed backing the admin dashboard's live map —
/// receives every active trip's status change and every driver's location
/// update system-wide (ws/dispatch/ on the backend), not scoped to one trip.
class DispatchWsService {
  DispatchWsService._();
  static final instance = DispatchWsService._();

  static const _wsBase = String.fromEnvironment(
    'WS_BASE',
    defaultValue: 'wss://tibasafari-backend.onrender.com',
  );

  WebSocketChannel? _channel;
  bool _wanted = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final _tripUpdateController = StreamController<TripUpdateEvent>.broadcast();
  final _driverLocationController = StreamController<DriverLocationEvent>.broadcast();

  Stream<TripUpdateEvent> get tripUpdates => _tripUpdateController.stream;
  Stream<DriverLocationEvent> get driverLocations => _driverLocationController.stream;

  void connect() {
    if (_wanted && _channel != null) return;
    _wanted = true;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _openChannel();
  }

  void _openChannel() {
    final token = AuthStorage.accessToken;
    if (token == null) return;
    // No ?token= here — the JWT is sent as the first WS message instead
    // (see below), so it never ends up in a proxy/server access log.
    final uri = Uri.parse('$_wsBase/ws/dispatch/');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    channel.stream.listen(
      (raw) {
        try {
          final data = json.decode(raw as String) as Map<String, dynamic>;
          switch (data['type']) {
            case 'trip_update':
              _tripUpdateController.add(TripUpdateEvent.fromJson(data));
            case 'driver_location':
              _driverLocationController.add(DriverLocationEvent.fromJson(data));
          }
        } catch (_) {}
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
    channel.ready.then((_) {
      if (_channel == channel) {
        channel.sink.add(json.encode({'type': 'auth', 'token': token}));
      }
    }).catchError((_) {});
  }

  void _scheduleReconnect() {
    _channel = null;
    if (!_wanted) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: (_reconnectAttempts * 2).clamp(2, 10));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_wanted) _openChannel();
    });
  }

  void disconnect() {
    _wanted = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _reconnectAttempts = 0;
  }
}
