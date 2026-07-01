import 'package:flutter/material.dart';
import 'package:patient_app/core/services/trip_api_service.dart';
import 'package:patient_app/core/theme/app_theme.dart';

const Color _cTeal = AppColors.primary;
const Color _cTealDark = AppColors.primaryDark;
const Color _cTealDeep = AppColors.primaryDeep;
const Color _cTealLight = AppColors.primaryExtraLight;
const Color _cBorder = AppColors.border;
const Color _cMuted = AppColors.textSecondary;
const Color _cMutedLight = AppColors.textMuted;
const Color _cError = AppColors.error;
const Color _cBg = AppColors.background;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final raw = await TripApiService.instance.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = raw.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _isLoading = false; });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await TripApiService.instance.markAllNotificationsRead();
      setState(() {
        _notifications = _notifications
            .map((n) => {...n, 'is_read': true})
            .toList();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('All notifications marked as read'),
          backgroundColor: _cTeal,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {}
  }

  Future<void> _markRead(Map<String, dynamic> notif) async {
    if (notif['is_read'] == true) return;
    final id = notif['id'] as String;
    try {
      await TripApiService.instance.markNotificationRead(id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx >= 0) _notifications[idx] = {..._notifications[idx], 'is_read': true};
      });
    } catch (_) {}
  }

  bool get _hasUnread => _notifications.any((n) => n['is_read'] != true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _cTealDark,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _cTealDeep),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _cTealLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Mark all read',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _cTeal),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? _buildShimmer()
          : _error != null
              ? _buildError()
              : _notifications.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _cTeal,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        itemCount: _notifications.length,
                        itemBuilder: (ctx, i) {
                          final n = _notifications[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _NotifCard(
                              notif: n,
                              onTap: () => _showDetail(n),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  void _showDetail(Map<String, dynamic> n) {
    _markRead(n);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotifDetailSheet(notif: n),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: _cBg, borderRadius: BorderRadius.circular(14))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 14, width: 140, color: _cBg),
            const SizedBox(height: 8),
            Container(height: 12, color: _cBg),
            const SizedBox(height: 4),
            Container(height: 12, width: 90, color: _cBg),
          ])),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 100, height: 100,
          decoration: const BoxDecoration(color: _cTealLight, shape: BoxShape.circle),
          child: const Icon(Icons.notifications_none_rounded, size: 50, color: _cTeal),
        ),
        const SizedBox(height: 20),
        const Text('No Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _cTealDeep)),
        const SizedBox(height: 8),
        const Text('You\'re all caught up!', style: TextStyle(fontSize: 14, color: _cMuted)),
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded, size: 54, color: _cError),
          const SizedBox(height: 16),
          Text(_error ?? 'Failed to load notifications', style: const TextStyle(fontSize: 14, color: _cMuted), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _cTeal, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Notification Card ─────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final Map<String, dynamic> notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRead = notif['is_read'] == true;
    final title = notif['title'] as String? ?? '';
    final message = notif['message'] as String? ?? '';
    final createdAt = DateTime.tryParse(notif['created_at'] as String? ?? '');
    final timeAgo = createdAt != null ? _timeAgo(createdAt) : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: isRead ? Colors.white : _cTealLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isRead ? _cBorder : _cTeal.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: _cTeal.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: _cTeal.withValues(alpha: isRead ? 0.08 : 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_iconForNotif(notif), size: 22, color: _cTeal),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(title, style: TextStyle(
                        fontSize: 14, fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, color: _cTealDeep,
                      )),
                    ),
                    if (!isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: _cTeal, shape: BoxShape.circle)),
                  ]),
                  const SizedBox(height: 5),
                  Text(message, style: const TextStyle(fontSize: 12.5, color: _cMuted, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.access_time_rounded, size: 11, color: _cMutedLight),
                    const SizedBox(width: 3),
                    Text(timeAgo, style: const TextStyle(fontSize: 11, color: _cMutedLight, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  IconData _iconForNotif(Map<String, dynamic> n) {
    final meta = n['metadata'];
    if (meta is Map) {
      final type = meta['type'] as String? ?? '';
      if (type.contains('trip') || type.contains('ride')) return Icons.directions_car_rounded;
      if (type.contains('assign')) return Icons.person_add_rounded;
      if (type.contains('cancel')) return Icons.cancel_rounded;
      if (type.contains('complete')) return Icons.check_circle_rounded;
    }
    return Icons.notifications_rounded;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Detail Bottom Sheet ───────────────────────────────────────────────────────

class _NotifDetailSheet extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _NotifDetailSheet({required this.notif});

  @override
  Widget build(BuildContext context) {
    final title = notif['title'] as String? ?? '';
    final message = notif['message'] as String? ?? '';
    final createdAt = DateTime.tryParse(notif['created_at'] as String? ?? '');
    final timeStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: _cBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: _cTealLight, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.notifications_rounded, size: 26, color: _cTeal),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _cTealDeep)),
              if (timeStr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(timeStr, style: const TextStyle(fontSize: 12, color: _cMuted)),
              ],
            ])),
          ]),
          const SizedBox(height: 20),
          const Divider(color: _cBorder),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(message, style: const TextStyle(fontSize: 15, color: _cTealDeep, height: 1.6, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cTeal, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Got it', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}
