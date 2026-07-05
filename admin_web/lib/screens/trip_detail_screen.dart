import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class TripDetailScreen extends StatefulWidget {
  final NavState nav;
  const TripDetailScreen({super.key, required this.nav});
  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  Future<Map<String, dynamic>> _load() async {
    return ApiService.get('/trips/${widget.nav.selectedTripId}/');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingRows();
        }
        // The response is the trip dict directly (ApiService unwraps the envelope).
        final t = Trip.fromJson(snap.data!);
        final meta = tripStatus(t.status);
        return PageScaffold(
          title: t.reference,
          description: 'Started ${formatDate(t.startedAt, withTime: true)}',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => widget.nav.navigate(ViewKey.tripsAll),
          ),
          actions: [StatusBadge(tone: meta.tone, label: meta.label, dot: true)],
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 900;
            final left = _left(t);
            final right = _right(t);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: left),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: right),
                ],
              );
            }
            return Column(children: [left, const SizedBox(height: 16), right]);
          }),
        );
      },
    );
  }

  Widget _left(Trip t) {
    return SectionCard(
      title: 'Route & Timing',
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 500 ? 2 : 1;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 3.2,
          children: [
            InfoRow(label: 'Pickup', value: Text(t.pickup)),
            InfoRow(label: 'Drop-off', value: Text(t.dropoff)),
            InfoRow(
                label: 'Started',
                value: Text(formatDate(t.startedAt, withTime: true))),
            InfoRow(
                label: 'Ended',
                value: Text(t.endedAt != null
                    ? formatDate(t.endedAt!, withTime: true)
                    : 'In progress')),
            InfoRow(
                label: 'Distance',
                value: Text('${t.distanceKm} km')),
            InfoRow(
                label: 'Fare',
                value: Text(formatCurrency(t.fare),
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        );
      }),
    );
  }

  Widget _right(Trip t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (t.patientName.isNotEmpty)
          SectionCard(
            title: 'Patient',
            child: InkWell(
              onTap: () => widget.nav.openDetail('patient', t.patientId),
              child: Row(children: [
                AvatarCircle(name: t.patientName, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(t.patientName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      if (t.patientEmail.isNotEmpty)
                        Text(t.patientEmail,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted)),
                    ])),
              ]),
            ),
          ),
        const SizedBox(height: 16),
        if (t.driverName.isNotEmpty)
          SectionCard(
            title: 'Driver',
            child: InkWell(
              onTap: () => widget.nav.openDetail('driver', t.driverId),
              child: Row(children: [
                AvatarCircle(
                    name: t.driverName,
                    color: avatarColor(null)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(t.driverName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      if (t.driverEmail.isNotEmpty)
                        Text(t.driverEmail,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted)),
                    ])),
              ]),
            ),
          ),
        const SizedBox(height: 16),
        if (t.vehicle != null)
          SectionCard(
            title: 'Vehicle',
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_car,
                    size: 18, color: Color(0xFF0EA5E9)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(t.vehicle!.plate,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(
                        '${t.vehicle!.model} · ${vehicleTypeLabel(t.vehicle!.type)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textMuted)),
                  ])),
            ]),
          ),
        const SizedBox(height: 16),
        _TripChatSection(tripId: t.id),
      ],
    );
  }
}

/// Lets dispatch/staff read and reply to the trip chat between patient and
/// driver. Polls for new messages rather than opening a WebSocket, since
/// admin_web has no existing WS client infrastructure.
class _TripChatSection extends StatefulWidget {
  final String tripId;
  const _TripChatSection({required this.tripId});

  @override
  State<_TripChatSection> createState() => _TripChatSectionState();
}

class _TripChatSectionState extends State<_TripChatSection> {
  List<Map<String, dynamic>> _messages = [];
  String? _myUserId;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _pollTimer;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final me = await ApiService.get('/auth/profile/');
      _myUserId = me['id']?.toString();
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.list('/trips/${widget.tripId}/messages/');
      if (!mounted) return;
      setState(() {
        _messages = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load messages';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ApiService.post('/trips/${widget.tripId}/messages/', {'body': body});
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Trip Chat',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!,
                  style: const TextStyle(color: AppTheme.textMuted)),
            )
          else if (_messages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No messages yet.',
                  style: TextStyle(color: AppTheme.textMuted)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  final isMe = m['sender']?.toString() == _myUserId;
                  return Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: isMe
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (m['sender_name'] ?? 'Unknown').toString(),
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                          Text((m['body'] ?? '').toString(),
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Reply as dispatch…',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
