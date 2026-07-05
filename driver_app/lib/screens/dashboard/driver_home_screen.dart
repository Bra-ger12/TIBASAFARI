import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/models/driver_session.dart';
import '../../core/theme/colors.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_storage.dart';
import '../../services/driver_service.dart';
import '../../services/location_service.dart';
import '../../services/notifications_ws_service.dart';
import '../../services/offline_queue_service.dart';
import '../profile/driver_documents_screen.dart';
import '../profile/driver_profile_sub_screens.dart';
import '../trips/active_trip_map_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  final DriverSession session;
  const DriverHomeScreen({super.key, required this.session});
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with TickerProviderStateMixin {
  late DriverSession _session;
  int _tab = 0;
  bool _loading = false;
  String? _error;
  StreamSubscription<DriverNotification>? _notifSub;
  int _refreshGeneration = 0;

  static const _wsBase = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://tibasafari-backend.onrender.com',
  );

  late final AnimationController _entryCtrl;
  late final List<Animation<double>> _entryFades;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entryFades = List.generate(5, (i) {
      final start = i * 0.08;
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(start, (start + 0.5).clamp(0, 1),
              curve: Curves.easeOutCubic),
        ),
      );
    });
    _entryCtrl.forward();
    _refresh();
    _connectNotifications();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _notifSub?.cancel();
    super.dispose();
  }

  /// Listens for the backend's real-time "New Trip Assigned" push
  /// (sent by TripService.assign_driver over ws/notifications/) so the
  /// dashboard's assigned-trip list updates without a manual pull-to-refresh.
  Future<void> _connectNotifications() async {
    final token = await AuthStorage.instance.getAccessToken();
    if (token == null || !mounted) return;
    NotificationsWsService.instance.connect(token: token, wsBaseUrl: _wsBase);
    _notifSub =
        NotificationsWsService.instance.notificationStream.listen((n) async {
      final tripId = n.metadata['trip_id'];
      if (tripId != null) await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          n.title.isNotEmpty ? '${n.title}: ${n.message}' : n.message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: cTeal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: tripId != null
            ? SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () => setState(() => _tab = 0),
              )
            : null,
      ));
    });
  }

  Future<void> _refresh() async {
    final generation = ++_refreshGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final updated =
          await DriverService.instance.fetchSession(_session.driverId);
      // Discard this response if a newer refresh has since started —
      // otherwise a slower in-flight call can overwrite fresher data
      // (e.g. the initial load resolving after a notification-triggered
      // refresh already picked up a newly assigned trip).
      if (mounted && generation == _refreshGeneration) {
        setState(() => _session = updated);
      }
    } catch (e) {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _refreshGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleOnline() async {
    final next = !_session.isOnline;
    setState(() => _session = _session.copyWith(isOnline: next));
    try {
      await DriverService.instance
          .setOnlineStatus(driverUid: _session.driverId, isOnline: next);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next ? 'You are now Online' : 'You are now Offline',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: next ? cTeal : const Color(0xFF475569),
        ));
      }
    } catch (e) {
      setState(() => _session = _session.copyWith(isOnline: !next));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Status update failed: $e'),
          backgroundColor: cError,
        ));
      }
    }
  }

  Future<void> _acceptTrip(String tripId) async {
    setState(() => _loading = true);
    try {
      final updated = await DriverService.instance
          .acceptTrip(driverUid: _session.driverId, tripId: tripId);
      final trips =
          _session.assignedTrips.map((t) => t.id == tripId ? updated : t).toList();
      setState(() => _session = _session.copyWith(assignedTrips: trips));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Trip accepted!',
              style: TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: cTeal,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: cError,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMap(DriverAssignedTrip trip) async {
    final token = await AuthStorage.instance.getAccessToken() ?? '';
    if (!mounted) return;
    final nav = Navigator.of(context); // capture before async gap
    final done = await nav.push<bool>(MaterialPageRoute(
      builder: (_) => ActiveTripMapScreen(
        trip: trip,
        token: token,
        driverUid: _session.driverId,
      ),
    ));
    if (done == true) await _refresh();
  }

  Future<void> _openProfileSub(Widget screen) async {
    final nav = Navigator.of(context);
    final saved = await nav.push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (saved == true) await _refresh();
  }

  Future<void> _triggerSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Send Emergency Alert?',
            style: TextStyle(fontWeight: FontWeight.w800, color: cError)),
        content: const Text(
            'This immediately notifies dispatch with your location. Only use this in a real emergency.',
            style: TextStyle(color: cMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: cMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: cError,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Send SOS', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final position = await LocationService.instance.getCurrentPosition();
      final notified = await DriverService.instance.triggerSos(
        tripId: _session.currentTripId,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(notified > 0
            ? 'Emergency alert sent to dispatch'
            : 'Alert sent, but no dispatcher is currently reachable'),
        backgroundColor: cError,
        behavior: SnackBarBehavior.floating,
      ));
    } on ActionQueuedException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: cAmber,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send alert: $e'),
          backgroundColor: cError,
        ));
      }
    }
  }

  void _showTripSheet(DriverAssignedTrip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TripSheet(trip: trip),
    );
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w800, color: cText)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: cMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: cMuted, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(color: cError, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      NotificationsWsService.instance.disconnect();
      await DriverService.instance.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _fade(int i, Widget child) => FadeTransition(
        opacity: _entryFades[i],
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(_entryFades[i]),
          child: child,
        ),
      );

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'D';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  static String _fmtTzs(int v) => v
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},');

  static String _greet() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: Column(
        children: [
          Expanded(
            child: _loading && _session.assignedTrips.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: cTeal))
                : _error != null && _session.assignedTrips.isEmpty
                    ? _ErrorView(message: _error!, onRetry: _refresh)
                    : IndexedStack(
                        index: _tab,
                        children: [
                          _buildHomeTab(),
                          _buildActiveTripTab(),
                          _buildHistoryTab(),
                          _buildEarningsTab(),
                          _buildProfileTab(),
                        ],
                      ),
          ),
          _BottomNav(
            currentIndex: _tab,
            onTab: (i) => setState(() => _tab = i),
          ),
        ],
      ),
    );
  }

  // ── Home tab ───────────────────────────────────────────────────────────────

  Widget _buildHomeTab() {
    final pending = _session.assignedTrips
        .where((t) =>
            t.status == TripAssignmentStatus.assigned ||
            t.status == TripAssignmentStatus.accepted)
        .toList();

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 16, 20, 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [cDark, cDarkMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cTeal.withValues(alpha: 0.18),
                  border: Border.all(color: cTeal.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Text(
                    _initials(_session.displayName),
                    style: const TextStyle(
                        color: cTeal, fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greet(),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    Text(
                      _session.displayName.isNotEmpty
                          ? _session.displayName
                          : 'Driver',
                      style: AppFonts.sora(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              // Online indicator pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _session.isOnline
                      ? cTeal.withValues(alpha: 0.18)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _session.isOnline
                        ? cTeal.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _session.isOnline ? cTeal : cGrey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _session.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                        color: _session.isOnline ? cTeal : cGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              // Notification bell
              GestureDetector(
                onTap: () => Navigator.pushNamed(
                    context, AppRoutes.notifications),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_none_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: cTeal,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status toggle card
                  _fade(0, _StatusCard(
                    isOnline: _session.isOnline,
                    onToggle: _toggleOnline,
                  )),
                  const SizedBox(height: 12),
                  _fade(0, _SosButton(onTap: _triggerSos)),
                  const SizedBox(height: 12),
                  _fade(0, const _SyncBanner()),
                  const SizedBox(height: 16),

                  // Stats row
                  _fade(1, _StatsRow(
                    tripsToday: _session.tripsToday,
                    earningsTzs: _session.earningsTodayTzs,
                    rating: _session.rating,
                  )),
                  const SizedBox(height: 24),

                  // Section header
                  _fade(2, _SectionHeader(
                    title: 'Assigned Trips',
                    count: pending.length,
                  )),
                  const SizedBox(height: 14),

                  // Trip list or empty state
                  _fade(3,
                    pending.isEmpty
                        ? _EmptyState(
                            icon: _session.isOnline
                                ? Icons.directions_car_rounded
                                : Icons.wifi_off_rounded,
                            title: _session.isOnline
                                ? 'Waiting for assignments'
                                : 'You are offline',
                            subtitle: _session.isOnline
                                ? 'New trips will appear here automatically.'
                                : 'Go online to start receiving trip requests.',
                          )
                        : Column(
                            children: pending
                                .map((t) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
                                      child: _TripCard(
                                        trip: t,
                                        onAccept: () => _acceptTrip(t.id),
                                        onDetails: () => _showTripSheet(t),
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Active trip tab ────────────────────────────────────────────────────────

  Widget _buildActiveTripTab() {
    final trip = _session.assignedTrips.cast<DriverAssignedTrip?>().firstWhere(
          (t) =>
              t!.status == TripAssignmentStatus.accepted ||
              t.status == TripAssignmentStatus.inProgress ||
              t.status == TripAssignmentStatus.arrived,
          orElse: () => null,
        );

    return SafeArea(
      child: trip == null
          ? const _EmptyState(
              icon: Icons.map_rounded,
              title: 'No Active Trip',
              subtitle:
                  'Once you accept a trip it will appear here with navigation.',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Trip',
                      style: AppFonts.sora(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: cText)),
                  const SizedBox(height: 16),
                  _ActiveTripCard(trip: trip),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => _openMap(trip),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cTeal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('Open Live Map',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── History tab ────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    final completed = _session.assignedTrips
        .where((t) => t.status == TripAssignmentStatus.completed)
        .toList();
    final cancelled = _session.assignedTrips
        .where((t) => t.status == TripAssignmentStatus.cancelled)
        .toList();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text('Trip History',
                style: AppFonts.sora(
                    fontSize: 22, fontWeight: FontWeight.w800, color: cText)),
          ),
          const SizedBox(height: 16),
          if (completed.isEmpty && cancelled.isEmpty)
            const Expanded(
              child: _EmptyState(
                icon: Icons.history_rounded,
                title: 'No Trip History',
                subtitle: 'Your completed trips will be listed here.',
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  if (completed.isNotEmpty) ...[
                    _buildHistorySectionLabel('Completed', completed.length,
                        cTeal),
                    const SizedBox(height: 10),
                    ...completed.map((t) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HistoryCard(trip: t),
                        )),
                    const SizedBox(height: 16),
                  ],
                  if (cancelled.isNotEmpty) ...[
                    _buildHistorySectionLabel('Cancelled', cancelled.length,
                        cError),
                    const SizedBox(height: 10),
                    ...cancelled.map((t) =>
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HistoryCard(trip: t),
                        )),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistorySectionLabel(String title, int count, Color color) {
    return Row(children: [
      Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: cText)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }

  // ── Earnings tab ───────────────────────────────────────────────────────────

  Widget _buildEarningsTab() {
    final completed = _session.assignedTrips
        .where((t) => t.status == TripAssignmentStatus.completed)
        .toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Earnings",
                style: AppFonts.sora(
                    fontSize: 22, fontWeight: FontWeight.w800, color: cText)),
            const SizedBox(height: 16),

            // Earnings hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [cDark, cDarkMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: cDark.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cTeal.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: cTeal),
                          SizedBox(width: 4),
                          Text("Today",
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: cTeal)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    'TSh ${_fmtTzs(_session.earningsTodayTzs)}',
                    style: AppFonts.sora(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text("Today's total earnings",
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _EarnStat(
                          label: 'Trips Today',
                          value: '${_session.tripsToday}'),
                      const SizedBox(width: 24),
                      _EarnStat(
                          label: 'Completion',
                          value: _session.formattedCompletionRate),
                      const SizedBox(width: 24),
                      _EarnStat(
                          label: 'Rating',
                          value: _session.formattedRating),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Weekly chart
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Weekly Trips",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cText)),
                  const SizedBox(height: 16),
                  _WeeklyChart(
                    values: _session.weeklyCompletedTripCounts,
                    days: _session.weeklyDayLabels,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recent trips
            if (completed.isNotEmpty) ...[
              const Text("Completed Today",
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: cText)),
              const SizedBox(height: 12),
              ...completed.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HistoryCard(trip: t),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  // ── Profile tab ────────────────────────────────────────────────────────────

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + 24, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [cDark, cDarkMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cTeal.withValues(alpha: 0.18),
                  border: Border.all(color: cTeal, width: 2.5),
                ),
                child: Center(
                  child: Text(
                    _initials(_session.displayName),
                    style: const TextStyle(
                        color: cTeal, fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(_session.displayName,
                  style: AppFonts.sora(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(_session.phone,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 13)),
              if (_session.vehiclePlate.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: cTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: cTeal.withValues(alpha: 0.35)),
                  ),
                  child: Text(_session.vehiclePlate,
                      style: const TextStyle(
                          color: cTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
              ],
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats grid
                Row(children: [
                  _ProfileStat(
                    icon: Icons.directions_car_rounded,
                    label: 'Total Trips',
                    value: '${_session.totalTrips}',
                  ),
                  const SizedBox(width: 12),
                  _ProfileStat(
                    icon: Icons.star_rounded,
                    label: 'Rating',
                    value: _session.formattedRating,
                    accent: cAmber,
                  ),
                  const SizedBox(width: 12),
                  _ProfileStat(
                    icon: Icons.check_circle_rounded,
                    label: 'Completion',
                    value: _session.formattedCompletionRate,
                    accent: cGreen,
                  ),
                ]),
                const SizedBox(height: 24),

                const Text("Account",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cMuted,
                        letterSpacing: 0.8)),
                const SizedBox(height: 10),

                _MenuItem(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit Profile',
                  onTap: () => _openProfileSub(EditProfileScreen(session: _session)),
                ),
                _MenuItem(
                  icon: Icons.directions_car_outlined,
                  title: 'My Vehicle',
                  onTap: () => _openProfileSub(MyVehicleScreen(session: _session)),
                ),
                _MenuItem(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.notifications),
                ),
                _MenuItem(
                  icon: Icons.fact_check_outlined,
                  title: 'Documents & Compliance',
                  onTap: () => _openProfileSub(const DriverDocumentsScreen()),
                ),
                const SizedBox(height: 8),
                const Text("Support",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cMuted,
                        letterSpacing: 0.8)),
                const SizedBox(height: 10),
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () => _openProfileSub(const DriverHelpSupportScreen()),
                ),
                _MenuItem(
                  icon: Icons.logout_rounded,
                  title: 'Sign Out',
                  color: cError,
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTab;
  const _BottomNav({required this.currentIndex, required this.onTab});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.map_outlined, Icons.map_rounded, 'Trip'),
    (Icons.history_outlined, Icons.history_rounded, 'History'),
    (Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded, 'Earnings'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
          12, 0, 12, MediaQuery.of(context).padding.bottom + 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: cSurface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: _items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final active = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTab(i),
              behavior: HitTestBehavior.opaque,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 24 : 0,
                  height: 3,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: cTeal,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(active ? item.$2 : item.$1,
                    size: 22, color: active ? cTeal : cMutedLight),
                const SizedBox(height: 3),
                Text(
                  item.$3,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        active ? FontWeight.w800 : FontWeight.w500,
                    color: active ? cTeal : cMutedLight,
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── SOS button ────────────────────────────────────────────────────────────────

class _SosButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SosButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: cError.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cError.withValues(alpha: 0.25), width: 1.5),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.emergency_share_rounded, size: 18, color: cError),
            SizedBox(width: 8),
            Text('Emergency SOS',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cError)),
          ]),
        ),
      ),
    );
  }
}

// ── Offline sync banner ─────────────────────────────────────────────────────

class _SyncBanner extends StatefulWidget {
  const _SyncBanner();

  @override
  State<_SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends State<_SyncBanner> {
  int _pending = 0;
  bool _syncing = false;
  late final StreamSubscription<int> _sub;

  @override
  void initState() {
    super.initState();
    OfflineQueueService.instance.pendingCount().then((count) {
      if (mounted) setState(() => _pending = count);
    });
    _sub = OfflineQueueService.instance.pendingCountStream.listen((count) {
      if (mounted) setState(() => _pending = count);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _retryNow() async {
    setState(() => _syncing = true);
    await OfflineQueueService.instance.flush();
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_pending == 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: cAmber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _pending == 1
                  ? '1 action waiting to sync'
                  : '$_pending actions waiting to sync',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: cAmber),
            ),
          ),
          _syncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cAmber),
                )
              : GestureDetector(
                  onTap: _retryNow,
                  child: const Text('Retry',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: cAmber,
                          decoration: TextDecoration.underline)),
                ),
        ],
      ),
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onToggle;
  const _StatusCard({required this.isOnline, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? [cTeal, cTealDark]
              : [const Color(0xFF2D3748), const Color(0xFF374151)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? cTeal : Colors.black).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? Colors.white : cGrey,
                    boxShadow: isOnline
                        ? [BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 6)]
                        : [],
                  ),
                ),
                Text(
                  isOnline ? 'You are Online' : 'You are Offline',
                  style: AppFonts.sora(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
              ]),
              const SizedBox(height: 3),
              Text(
                isOnline
                    ? 'Receiving new trip assignments'
                    : 'Tap to go online and receive trips',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Text(
                isOnline ? 'Go Offline' : 'Go Online',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int tripsToday;
  final int earningsTzs;
  final double rating;
  const _StatsRow(
      {required this.tripsToday,
      required this.earningsTzs,
      required this.rating});

  String _fmt(int v) => v
      .toString()
      .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _StatTile(
          icon: Icons.directions_car_rounded,
          color: cBlue,
          value: '$tripsToday',
          label: "Trips Today",
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatTile(
          icon: Icons.payments_rounded,
          color: cAmber,
          value: _fmt(earningsTzs),
          label: "TSh Earned",
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatTile(
          icon: Icons.star_rounded,
          color: cOrange,
          value: rating.toStringAsFixed(1),
          label: "Rating",
        ),
      ),
    ]);
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatTile(
      {required this.icon,
      required this.color,
      required this.value,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: cSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: cText)),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 10, color: cMutedLight),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title,
          style: AppFonts.sora(
              fontSize: 16, fontWeight: FontWeight.w800, color: cText)),
      if (count > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cTealLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count Active',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cTealDeep)),
        ),
    ]);
  }
}

// ── Trip card ─────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final DriverAssignedTrip trip;
  final VoidCallback onAccept;
  final VoidCallback onDetails;
  const _TripCard(
      {required this.trip,
      required this.onAccept,
      required this.onDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Patient + badge
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cTealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded,
                  size: 20, color: cTealDeep),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.patientName,
                        style: AppFonts.sora(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: cText)),
                    Text(trip.appointmentType,
                        style: const TextStyle(
                            fontSize: 12, color: cMuted)),
                  ]),
            ),
            _StatusBadge(status: trip.status),
          ]),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              Container(width: 1.5, height: 1.5, color: cBorder),
              const Expanded(
                  child: Divider(color: cBorder, height: 1)),
            ]),
          ),

          // Route
          _RouteTimeline(
              pickup: trip.pickupAddress, dest: trip.destination),

          // Special requirements
          if (trip.specialRequirements.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RequirementsChips(items: trip.specialRequirements),
          ],

          // Time row
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              const Icon(Icons.schedule_rounded,
                  size: 14, color: cMutedLight),
              const SizedBox(width: 5),
              Text('Pickup at ${trip.pickupTime}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: cMuted,
                      fontWeight: FontWeight.w600)),
            ]),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: _Btn(
                  label: 'Accept Trip',
                  bg: cTeal,
                  fg: Colors.white,
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Btn(
                  label: 'Details',
                  bg: cTealLight,
                  fg: cTealDeep,
                  onTap: onDetails,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  final DriverAssignedTrip trip;
  const _ActiveTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cBorder),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trip.patientName,
                  style: AppFonts.sora(
                      fontSize: 16, fontWeight: FontWeight.w800, color: cText)),
              const SizedBox(height: 2),
              Text(trip.appointmentType,
                  style: const TextStyle(fontSize: 12, color: cMuted)),
            ]),
          ),
          _StatusBadge(status: trip.status),
        ]),
        const SizedBox(height: 16),
        _RouteTimeline(
            pickup: trip.pickupAddress, dest: trip.destination),
        if (trip.specialRequirements.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RequirementsChips(items: trip.specialRequirements),
        ],
      ]),
    );
  }
}

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final DriverAssignedTrip trip;
  const _HistoryCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final done = trip.status == TripAssignmentStatus.completed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cBorder),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (done ? cTeal : cError).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            done ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: done ? cTeal : cError,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(trip.patientName,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cText)),
            const SizedBox(height: 2),
            Text(trip.destination,
                style: const TextStyle(fontSize: 12, color: cMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(trip.pickupTime,
              style: const TextStyle(
                  fontSize: 11, color: cMutedLight, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          _StatusBadge(status: trip.status),
        ]),
      ]),
    );
  }
}

// ── Trip detail bottom sheet ──────────────────────────────────────────────────

class _TripSheet extends StatelessWidget {
  final DriverAssignedTrip trip;
  const _TripSheet({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: cBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: cBorder, borderRadius: BorderRadius.circular(2)),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cBorder),
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cTealLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: cTealDeep, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(trip.patientName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800, color: cText)),
                    Text(trip.appointmentType,
                        style: const TextStyle(fontSize: 13, color: cMuted)),
                  ]),
                ),
                _StatusBadge(status: trip.status),
              ]),
              const SizedBox(height: 16),
              const Divider(color: cBorder, height: 1),
              const SizedBox(height: 16),
              _DetailRow(Icons.location_on_rounded, 'Pickup',
                  trip.pickupAddress, cBlue),
              const SizedBox(height: 10),
              _DetailRow(Icons.flag_rounded, 'Destination',
                  trip.destination, cTeal),
              const SizedBox(height: 10),
              _DetailRow(Icons.schedule_rounded, 'Pickup Time',
                  trip.pickupTime, cAmber),
              if (trip.specialRequirements.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailRow(Icons.warning_amber_rounded, 'Requirements',
                    trip.specialRequirements.join(', '), cOrange),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: cTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Close',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _DetailRow(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: cMuted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: cText)),
        ]),
      ),
    ]);
  }
}

// ── Route timeline ────────────────────────────────────────────────────────────

class _RouteTimeline extends StatelessWidget {
  final String pickup;
  final String dest;
  const _RouteTimeline({required this.pickup, required this.dest});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: cTeal, width: 3),
          ),
        ),
        Container(
          width: 1.5,
          height: 24,
          margin: const EdgeInsets.symmetric(vertical: 2),
          color: cBorder,
        ),
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: cError, borderRadius: BorderRadius.circular(3)),
        ),
      ]),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          _RouteStop(label: 'Pickup', address: pickup),
          const SizedBox(height: 12),
          _RouteStop(label: 'Destination', address: dest),
        ]),
      ),
    ]);
  }
}

class _RouteStop extends StatelessWidget {
  final String label;
  final String address;
  const _RouteStop({required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 10,
              color: cMutedLight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4)),
      const SizedBox(height: 2),
      Text(address,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: cText)),
    ]);
  }
}

// ── Requirements chips ────────────────────────────────────────────────────────

class _RequirementsChips extends StatelessWidget {
  final List<String> items;
  const _RequirementsChips({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cAmber.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, size: 14, color: cAmber),
        const SizedBox(width: 6),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items
                .map((r) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: cAmber.withValues(alpha: 0.4)),
                      ),
                      child: Text(r,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cText)),
                    ))
                .toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final TripAssignmentStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      TripAssignmentStatus.assigned   => ('Assigned', const Color(0xFFEFF6FF), cBlue),
      TripAssignmentStatus.accepted   => ('Accepted', cTealLight, cTealDeep),
      TripAssignmentStatus.inProgress => ('En Route', const Color(0xFFFFFBEB), cAmber),
      TripAssignmentStatus.arrived    => ('Arrived', const Color(0xFFEFF6FF), cBlue),
      TripAssignmentStatus.completed  => ('Completed', cTealLight, cTealDeep),
      TripAssignmentStatus.cancelled  => ('Cancelled', const Color(0xFFFEF2F2), cError),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ── Generic button ────────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _Btn(
      {required this.label,
      required this.bg,
      required this.fg,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
        ),
      ),
    );
  }
}

// ── Weekly chart (bar chart) ──────────────────────────────────────────────────

class _WeeklyChart extends StatelessWidget {
  final List<int> values;
  final List<String> days;
  const _WeeklyChart({required this.values, required this.days});

  @override
  Widget build(BuildContext context) {
    final todayIndex = days.length - 1;
    final maxVal = values.reduce((a, b) => a > b ? a : b).clamp(1, 99);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.asMap().entries.map((e) {
        final i = e.key;
        final isToday = i == todayIndex;
        final barH = (values[i] / maxVal * 72).clamp(4.0, 72.0);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${values[i]}',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday ? cTeal : cMuted)),
          const SizedBox(height: 4),
          Container(
            width: 26,
            height: barH,
            decoration: BoxDecoration(
              color: isToday ? cTeal : cTealLight,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Text(days[i],
              style: TextStyle(
                  fontSize: 10,
                  color: isToday ? cTeal : cMuted,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500)),
        ]);
      }).toList(),
    );
  }
}

// ── Earnings stat chip ────────────────────────────────────────────────────────

class _EarnStat extends StatelessWidget {
  final String label;
  final String value;
  const _EarnStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 3),
      Text(value,
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
    ]);
  }
}

// ── Profile stat tile ─────────────────────────────────────────────────────────

class _ProfileStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;
  const _ProfileStat(
      {required this.icon,
      required this.label,
      required this.value,
      this.accent});

  @override
  Widget build(BuildContext context) {
    final c = accent ?? cTeal;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: cSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cBorder),
        ),
        child: Column(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: c),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: cText)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 10, color: cMutedLight),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Menu item ─────────────────────────────────────────────────────────────────

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;
  const _MenuItem(
      {required this.icon,
      required this.title,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? cText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cBorder),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: c),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c))),
              Icon(Icons.chevron_right_rounded, color: cMutedLight, size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cTealLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 32, color: cMutedLight),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: cText),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: cMuted, height: 1.4),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cError.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.error_outline_rounded,
                size: 30, color: cError),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(fontSize: 14, color: cMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: cTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }
}
