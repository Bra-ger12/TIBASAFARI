import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class PatientNotification {
  final String id;
  final String title;
  final String message;
  final Map<String, dynamic> metadata;

  PatientNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.metadata,
  });

  factory PatientNotification.fromJson(Map<String, dynamic> j) =>
      PatientNotification(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        message: j['message'] as String? ?? '',
        metadata: (j['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// Connects to the patient's personal notification room (ws/notifications/)
/// so events like "Driver Assigned" (pushed by TripService.assign_driver,
/// including driver name/phone/vehicle in metadata) reach the app in real
/// time, without waiting for a manual refresh.
class NotificationsWsService {
  NotificationsWsService._();
  static final instance = NotificationsWsService._();

  WebSocketChannel? _channel;
  String? _connectedToken;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final _notificationController =
      StreamController<PatientNotification>.broadcast();

  Stream<PatientNotification> get notificationStream =>
      _notificationController.stream;

  static const _wsBase = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://tibasafari-backend.onrender.com',
  );

  void connect({required String token}) {
    if (_connectedToken == token && _channel != null) return;
    if (_connectedToken != token) disconnect();
    _connectedToken = token;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _openChannel();
  }

  void _openChannel() {
    final token = _connectedToken;
    if (token == null) return;
    // No ?token= here — the JWT is sent as the first WS message instead
    // (see below), so it never ends up in a proxy/server access log.
    final uri = Uri.parse('$_wsBase/ws/notifications/');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    channel.stream.listen(
      (raw) {
        try {
          final data = json.decode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'notification') {
            _notificationController.add(PatientNotification.fromJson(data));
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
    if (_connectedToken == null) return;
    _reconnectAttempts++;
    final delay = Duration(seconds: (_reconnectAttempts * 2).clamp(2, 10));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (_connectedToken != null) _openChannel();
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connectedToken = null;
    _reconnectAttempts = 0;
  }

  void dispose() {
    disconnect();
    _notificationController.close();
  }
}
