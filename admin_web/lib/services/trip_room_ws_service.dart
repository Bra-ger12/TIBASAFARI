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
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final _locationController = StreamController<Map<String, double>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<Map<String, double>> get locationStream => _locationController.stream;
  Stream<String> get statusStream => _statusController.stream;

  void connect(String tripId) {
    if (_activeTripId == tripId && _channel != null) return;
    if (_activeTripId != tripId) disconnect();
    final token = AuthStorage.accessToken;
    if (token == null) return;
    _activeTripId = tripId;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _openChannel();
  }

  void _openChannel() {
    final tripId = _activeTripId;
    final token = AuthStorage.accessToken;
    if (tripId == null || token == null) return;
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
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
  }

  /// Reconnects with a capped linear backoff (2s, 4s, ... up to 10s) rather
  /// than giving up — a dropped connection previously meant the dispatcher's
  /// live map/status view silently froze until the page was reopened.
  void _scheduleReconnect() {
    _channel = null;
    if (_activeTripId == null) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: (_reconnectAttempts * 2).clamp(2, 10));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_activeTripId != null) _openChannel();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _activeTripId = null;
    _reconnectAttempts = 0;
  }
}
