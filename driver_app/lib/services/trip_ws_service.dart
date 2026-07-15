import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/models/trip_message.dart';

/// Manages a WebSocket connection to a specific trip room.
/// The driver streams their GPS position; the app also receives
/// status-change events and chat messages pushed by the backend.
class TripWsService {
  TripWsService._();
  static final instance = TripWsService._();

  WebSocketChannel? _channel;
  String? _currentTripId;
  String? _token;
  String? _wsBaseUrl;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final _statusController = StreamController<String>.broadcast();
  final _chatController = StreamController<TripChatMessage>.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<TripChatMessage> get chatStream => _chatController.stream;

  void connect({
    required String tripId,
    required String token,
    required String wsBaseUrl,
  }) {
    if (_currentTripId == tripId && _channel != null) return;
    if (_currentTripId != tripId) disconnect();
    _currentTripId = tripId;
    _token = token;
    _wsBaseUrl = wsBaseUrl;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _openChannel();
  }

  void _openChannel() {
    final tripId = _currentTripId;
    final token = _token;
    final wsBaseUrl = _wsBaseUrl;
    if (tripId == null || token == null || wsBaseUrl == null) return;
    final uri = Uri.parse('$wsBaseUrl/ws/trips/$tripId/?token=$token');
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (raw) {
        try {
          final data = json.decode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'status') {
            _statusController.add(data['status'] as String);
          } else if (data['type'] == 'chat') {
            _chatController.add(TripChatMessage.fromJson(data));
          }
        } catch (_) {}
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
  }

  /// Reconnects with a capped linear backoff (2s, 4s, ... up to 10s) rather
  /// than giving up — a dropped mobile connection previously meant the
  /// driver silently stopped sending location updates (and receiving
  /// status/chat) for the rest of the trip with no recovery.
  void _scheduleReconnect() {
    _channel = null;
    if (_currentTripId == null) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: (_reconnectAttempts * 2).clamp(2, 10));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_currentTripId != null) _openChannel();
    });
  }

  void sendLocation(double lat, double lng) {
    _channel?.sink.add(
      json.encode({'type': 'location', 'lat': lat, 'lng': lng}),
    );
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _currentTripId = null;
    _token = null;
    _wsBaseUrl = null;
    _reconnectAttempts = 0;
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _chatController.close();
  }
}
