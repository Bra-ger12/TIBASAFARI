import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'auth_storage.dart';

/// Connects to a single trip's WebSocket room (ws/trips/{id}/) for the
/// admin Active Trip screen's live map — the driver's position and the
/// trip's status, in real time. Chat on that screen already polls via REST
/// separately and is unaffected by this.
class TripRoomWsService {
  TripRoomWsService._();
  static final instance = TripRoomWsService._();

  static const _wsBase = String.fromEnvironment(
    'WS_BASE',
    defaultValue: 'wss://tibasafari-backend.onrender.com',
  );

  WebSocketChannel? _channel;
  String? _activeTripId;

  final _locationController = StreamController<Map<String, double>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<Map<String, double>> get locationStream => _locationController.stream;
  Stream<String> get statusStream => _statusController.stream;

  void connect(String tripId) {
    if (_activeTripId == tripId) return;
    disconnect();
    final token = AuthStorage.accessToken;
    if (token == null) return;
    _activeTripId = tripId;
    final uri = Uri.parse('$_wsBase/ws/trips/$tripId/?token=$token');
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (raw) {
        try {
          final data = json.decode(raw as String) as Map<String, dynamic>;
          switch (data['type']) {
            case 'location':
              _locationController.add({
                'lat': (data['lat'] as num).toDouble(),
                'lng': (data['lng'] as num).toDouble(),
              });
            case 'status':
              _statusController.add(data['status'] as String);
          }
        } catch (_) {}
      },
      onDone: () => _activeTripId = null,
      onError: (_) => _activeTripId = null,
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _activeTripId = null;
  }
}
