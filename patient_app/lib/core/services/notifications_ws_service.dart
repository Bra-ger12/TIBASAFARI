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
  final _notificationController =
      StreamController<PatientNotification>.broadcast();

  Stream<PatientNotification> get notificationStream =>
      _notificationController.stream;

  static const _wsBase = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://tibasafari-backend.onrender.com',
  );

  void connect({required String token}) {
    if (_connectedToken == token) return;
    disconnect();
    _connectedToken = token;
    final uri = Uri.parse('$_wsBase/ws/notifications/?token=$token');
    _channel = WebSocketChannel.connect(uri);
    _channel!.stream.listen(
      (raw) {
        try {
          final data = json.decode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'notification') {
            _notificationController.add(PatientNotification.fromJson(data));
          }
        } catch (_) {}
      },
      onDone: () => _connectedToken = null,
      onError: (_) => _connectedToken = null,
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _connectedToken = null;
  }

  void dispose() {
    disconnect();
    _notificationController.close();
  }
}
