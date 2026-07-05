import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Patient-side trip tracking: subscribes to a trip room and receives
/// real-time driver location updates and trip status changes.
class TripTrackingService {
  TripTrackingService._();
  static final instance = TripTrackingService._();

  WebSocketChannel? _channel;
  String? _activeTripId;

  final _locationController =
      StreamController<Map<String, double>>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<Map<String, double>> get locationStream => _locationController.stream;
  Stream<String> get statusStream => _statusController.stream;

  static const _wsBase = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://tibasafari-backend.onrender.com',
  );

  void connect({required String tripId, required String token}) {
    if (_activeTripId == tripId) return;
    disconnect();
    _activeTripId = tripId;
    final uri = Uri.parse('$_wsBase/ws/trips/$tripId/?token=$token');
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      _onMessage,
      onDone: () => _activeTripId = null,
      onError: (_) => _activeTripId = null,
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _activeTripId = null;
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
      }
    } catch (_) {}
  }

  void dispose() {
    disconnect();
    _locationController.close();
    _statusController.close();
  }
}
