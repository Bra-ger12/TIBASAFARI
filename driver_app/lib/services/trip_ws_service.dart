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
  final _statusController = StreamController<String>.broadcast();
  final _chatController = StreamController<TripChatMessage>.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<TripChatMessage> get chatStream => _chatController.stream;

  void connect({
    required String tripId,
    required String token,
    required String wsBaseUrl,
  }) {
    if (_currentTripId == tripId) return;
    disconnect();
    _currentTripId = tripId;
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
      onDone: () => _currentTripId = null,
      onError: (_) => _currentTripId = null,
    );
  }

  void sendLocation(double lat, double lng) {
    _channel?.sink.add(
      json.encode({'type': 'location', 'lat': lat, 'lng': lng}),
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _currentTripId = null;
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _chatController.close();
  }
}
