import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thrown by [DriverService] when an action couldn't reach the backend due to
/// connectivity loss but was persisted to [OfflineQueueService] for automatic
/// retry — callers should show a "saved, will sync" message instead of an error.
class ActionQueuedException implements Exception {
  const ActionQueuedException();

  @override
  String toString() =>
      'No connection right now — this will sync automatically once you\'re back online.';
}

class QueuedAction {
  final String id;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime queuedAt;

  const QueuedAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'payload': payload,
        'queued_at': queuedAt.toIso8601String(),
      };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
        id: json['id'] as String,
        type: json['type'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        queuedAt:
            DateTime.tryParse(json['queued_at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Attempts to replay a queued action against the real API. Must return
/// `true` once the action should be dropped from the queue — either because
/// it succeeded, or because it failed in a way that will never succeed on
/// retry (e.g. the trip is no longer in a state where this action applies).
/// Return `false` only when the failure looks like a connectivity issue, so
/// the action stays queued for the next retry pass.
typedef ActionHandler = Future<bool> Function(Map<String, dynamic> payload);

/// Persists API actions (trip status updates, SOS alerts) that failed purely
/// due to connectivity loss, so they aren't silently dropped — they're
/// retried automatically on a timer and whenever [flush] is called.
class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  static const _prefsKey = 'driver_offline_action_queue';

  final Map<String, ActionHandler> _handlers = {};
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();
  Timer? _retryTimer;
  bool _flushing = false;

  /// Emits the current queue length whenever it changes. Does not replay the
  /// last value to new listeners — call [pendingCount] for the current count.
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  void registerHandler(String type, ActionHandler handler) {
    _handlers[type] = handler;
  }

  Future<List<QueuedAction>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const [];
    return raw
        .map((item) =>
            QueuedAction.fromJson(jsonDecode(item) as Map<String, dynamic>))
        .toList();
  }

  Future<void> _save(List<QueuedAction> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(items.length);
    }
  }

  Future<int> pendingCount() async => (await _load()).length;

  Future<void> enqueue(String type, Map<String, dynamic> payload) async {
    final items = await _load();
    items.add(QueuedAction(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      payload: payload,
      queuedAt: DateTime.now(),
    ));
    await _save(items);
  }

  /// Replays every queued action once. Safe to call repeatedly (e.g. from a
  /// timer, a pull-to-refresh, or app-resume) — concurrent calls are no-ops.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final items = await _load();
      if (items.isEmpty) return;
      final remaining = <QueuedAction>[];
      for (final item in items) {
        final handler = _handlers[item.type];
        if (handler == null) {
          remaining.add(item);
          continue;
        }
        try {
          final done = await handler(item.payload);
          if (!done) remaining.add(item);
        } catch (_) {
          remaining.add(item);
        }
      }
      await _save(remaining);
    } finally {
      _flushing = false;
    }
  }

  void startAutoRetry({Duration interval = const Duration(seconds: 20)}) {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(interval, (_) => flush());
  }

  void stopAutoRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}
