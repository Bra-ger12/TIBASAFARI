import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/trip_message.dart';

/// Patient-side trip tracking: subscribes to a trip room and receives
/// real-time driver location updates, trip status changes and chat
/// messages.
class TripTrackingService {
  TripTrackingService._();
  static final instance = TripTrackingService._();

  WebSocketChannel? _channel;
  String? _activeTripId;
  String? _token;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  final _locationController =
      StreamController<Map<String, double>>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _chatController = StreamController<TripChatMessage>.broadcast();

  Stream<Map<String, double>> get locationStream => _locationController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<TripChatMessage> get chatStream => _chatController.stream;

  static const _wsBase = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://tibasafari-backend.onrender.com',
  );

  void connect({required String tripId, required String token}) {
    if (_activeTripId == tripId && _channel != null) return;
    if (_activeTripId != tripId) disconnect();
    _activeTripId = tripId;
    _token = token;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _openChannel();
  }

  void _openChannel() {
    final tripId = _activeTripId;
    final token = _token;
    if (tripId == null || token == null) return;
    final uri = Uri.parse('$_wsBase/ws/trips/$tripId/?token=$token');
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      _onMessage,
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
  }

  /// Reconnects with a capped linear backoff (2s, 4s, ... up to 10s) rather
  /// than giving up — a dropped connection previously meant the live map
  /// and status badge silently froze for the rest of the trip with no
  /// recovery until the patient manually left and reopened the screen.
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
    _token = null;
    _reconnectAttempts = 0;
  }

  void _onMessage(dynamic raw) {
    try {
      final data = json.decode(raw as String) as Map<String, dynamic>;
      switch (data['type'] as String?) {
        case 'location':
          _locationController.add({
            'lat': (data['lat'] as num).toDouble(),
            'lng': (data['lng'] as num).toDouble(),
          });
        case 'status':
          _statusController.add(data['status'] as String);
        case 'chat':
          _chatController.add(TripChatMessage.fromJson(data));
      }
    } catch (_) {}
  }

  void dispose() {
    disconnect();
    _locationController.close();
    _statusController.close();
    _chatController.close();
  }
}
