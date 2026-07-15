import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/web_socket_channel.dart';

class DriverNotification {
  final String id;
  final String title;
  final String message;
  final Map<String, dynamic> metadata;

  DriverNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.metadata,
  });

  factory DriverNotification.fromJson(Map<String, dynamic> j) =>
      DriverNotification(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        message: j['message'] as String? ?? '',
        metadata: (j['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// Connects to the driver's personal notification room (ws/notifications/)
/// so events like "New Trip Assigned" (pushed by TripService.assign_driver)
/// reach the dashboard in real time, without waiting for a manual refresh.
///
/// Mobile sockets drop constantly (backgrounding, network handoff, DHCP
/// renewal) — without a reconnect loop the driver would silently stop
/// receiving live assignment updates for the rest of the session after the
/// first drop, with no visible error. This reconnects with backoff for as
/// long as [connect] has been called more recently than [disconnect].
class NotificationsWsService {
  NotificationsWsService._();
  static final instance = NotificationsWsService._();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  /// The token/URL we should be connected with. Null means the caller
  /// (e.g. logout) explicitly asked us to stop — no more reconnect attempts.
  String? _wantedToken;
  String? _wsBaseUrl;

  final _notificationController =
      StreamController<DriverNotification>.broadcast();

  Stream<DriverNotification> get notificationStream =>
      _notificationController.stream;

  void connect({required String token, required String wsBaseUrl}) {
    if (_wantedToken == token && (_channel != null || _reconnectTimer != null)) {
      return;
    }
    _wantedToken = token;
    _wsBaseUrl = wsBaseUrl;
    _reconnectAttempts = 0;
    _open();
  }

  void _open() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSub?.cancel();
    _channel?.sink.close();

    final token = _wantedToken;
    final wsBaseUrl = _wsBaseUrl;
    if (token == null || wsBaseUrl == null) return;

    // No ?token= here — the JWT is sent as the first WS message instead
    // (see below), so it never ends up in a proxy/server access log.
    final uri = Uri.parse('$wsBaseUrl/ws/notifications/');
    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _channelSub = channel.stream.listen(
      (raw) {
        _reconnectAttempts = 0;
        try {
          final data = json.decode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'notification') {
            _notificationController.add(DriverNotification.fromJson(data));
          }
        } catch (_) {}
      },
      onDone: _handleDrop,
      onError: (_) => _handleDrop(),
    );
    channel.ready.then((_) {
      if (_channel == channel) {
        channel.sink.add(json.encode({'type': 'auth', 'token': token}));
      }
    }).catchError((_) {});
  }

  void _handleDrop() {
    _channel = null;
    if (_wantedToken == null) return; // intentional disconnect — don't retry

    _reconnectAttempts++;
    final delaySeconds = min(30, pow(2, _reconnectAttempts).toInt());
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), _open);
  }

  /// Stops the connection and any pending reconnect attempts. Call on
  /// logout — call [connect] again to resume.
  void disconnect() {
    _wantedToken = null;
    _wsBaseUrl = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _notificationController.close();
  }
}
