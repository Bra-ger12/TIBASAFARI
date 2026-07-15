import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';

class NotificationsBroadcastScreen extends StatefulWidget {
  const NotificationsBroadcastScreen({super.key});
  @override
  State<NotificationsBroadcastScreen> createState() =>
      _NotificationsBroadcastScreenState();
}

class _NotificationsBroadcastScreenState
    extends State<NotificationsBroadcastScreen> {
  late Future<List<NotificationRecord>> _future;
  final _title = TextEditingController();
  final _message = TextEditingController();
  String _audience = 'all';
  String _channel = 'push';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<NotificationRecord>> _load() async {
    final items = await ApiService.list('/notifications/broadcasts/');
    return items.map(NotificationRecord.fromJson).toList();
  }

  Future<void> _send() async {
    if (_title.text.isEmpty || _message.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and message are required.')));
      return;
    }
    setState(() => _sending = true);
    try {
      final res = await ApiService.post('/notifications/broadcasts/', {
        'title': _title.text,
        'message': _message.text,
        'audience': _audience,
        'channel': _channel,
      });
      final n = NotificationRecord.fromJson(res);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Broadcast sent to ${n.recipients} recipients.')));
      _title.clear();
      _message.clear();
      setState(() => _future = _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Broadcast Notifications',
      description: 'Send push, SMS, or email notifications to user groups.',
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth > 900;
        final compose = _compose();
        final recent = _recent();
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: compose),
              const SizedBox(width: 16),
              Expanded(flex: 1, child: recent),
            ],
          );
        }
        return Column(children: [compose, const SizedBox(height: 16), recent]);
      }),
    );
  }

  Widget _compose() {
    return SectionCard(
      title: 'Compose Broadcast',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            decoration: const InputDecoration(labelText: 'Message'),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          const Text('Audience',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _audienceChip('all', 'All users', Icons.people),
              _audienceChip('drivers', 'Drivers', Icons.badge),
              _audienceChip('patients', 'Patients', Icons.people_outline),
              _audienceChip('admins', 'Admins', Icons.admin_panel_settings),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Channel',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _channelChip('push', 'Push'),
              _channelChip('sms', 'SMS'),
              _channelChip('email', 'Email'),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 16),
              label: const Text('Send Broadcast'),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _audienceChip(String value, String label, IconData icon) {
    final sel = _audience == value;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14),
        const SizedBox(width: 6),
        Text(label),
      ]),
      selected: sel,
      selectedColor: AppTheme.primary.withValues(alpha: 0.1),
      side: BorderSide(
          color: sel ? AppTheme.primary : AppTheme.border),
      onSelected: (_) => setState(() => _audience = value),
    );
  }

  Widget _channelChip(String value, String label) {
    final sel = _channel == value;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      selectedColor: AppTheme.primary.withValues(alpha: 0.1),
      side: BorderSide(
          color: sel ? AppTheme.primary : AppTheme.border),
      onSelected: (_) => setState(() => _channel = value),
    );
  }

  Widget _recent() {
    return SectionCard(
      title: 'Recent Broadcasts',
      padding: EdgeInsets.zero,
      child: FutureBuilder<List<NotificationRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()));
          }
          if (snap.hasError) {
            return ErrorState(
              message: '${snap.error}',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.campaign, title: 'No broadcasts yet.');
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: list.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppTheme.border),
              itemBuilder: (context, i) {
                final n = list[i];
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.campaign,
                        size: 16, color: Color(0xFF7C3AED)),
                  ),
                  title: Text(n.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          StatusBadge(
                              tone: StatusTone.slate, label: n.audience),
                          Text('· ${n.channel} · ${n.recipients} recipients · ${formatRelative(n.sentAt)}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
