import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/dispatch_ws_service.dart';
import '../services/format.dart';
import '../theme/app_theme.dart';
import '../widgets/kpi_card.dart';
import '../widgets/live_map.dart';
import '../widgets/nav.dart';
import '../widgets/shared.dart';
import '../widgets/status_badge.dart';

class DashboardScreen extends StatefulWidget {
  final NavState nav;
  const DashboardScreen({super.key, required this.nav});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late Future<_DashboardData> _future;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<ActiveTripMapItem>? _liveMapItems;
  StreamSubscription<TripUpdateEvent>? _tripUpdateSub;
  StreamSubscription<DriverLocationEvent>? _locationSub;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    DispatchWsService.instance.connect();
    _tripUpdateSub =
        DispatchWsService.instance.tripUpdates.listen(_onTripUpdate);
    _locationSub =
        DispatchWsService.instance.driverLocations.listen(_onDriverLocation);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tripUpdateSub?.cancel();
    _locationSub?.cancel();
    _refreshDebounce?.cancel();
    super.dispose();
  }

  static const _activeStatuses = {'ASSIGNED', 'ACCEPTED', 'EN_ROUTE', 'ARRIVED'};

  void _onTripUpdate(TripUpdateEvent event) {
    if (_liveMapItems == null) return;
    final items = _liveMapItems!;
    final index = items.indexWhere((t) => t.id == event.tripId);

    if (!_activeStatuses.contains(event.status)) {
      // Trip completed/cancelled/rejected back to the pool — drop its marker.
      if (index != -1) {
        setState(() => _liveMapItems = [...items]..removeAt(index));
      }
      return;
    }

    if (index != -1) {
      setState(() {
        final updated = [...items];
        updated[index] = items[index].copyWith(status: event.status);
        _liveMapItems = updated;
      });
    } else {
      // A trip we don't have full details for yet (newly assigned) —
      // debounce a targeted re-fetch rather than guessing its fields.
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(seconds: 1), _refreshMapItems);
    }
  }

  void _onDriverLocation(DriverLocationEvent event) {
    if (_liveMapItems == null) return;
    final items = _liveMapItems!;
    final index = items.indexWhere((t) => t.driverId == event.driverId);
    if (index == -1) return;
    setState(() {
      final updated = [...items];
      updated[index] =
          items[index].copyWith(vehicleLat: event.lat, vehicleLng: event.lng);
      _liveMapItems = updated;
    });
  }

  Future<void> _refreshMapItems() async {
    try {
      final items = await ApiService.list('/dashboard/active-trips/');
      if (!mounted) return;
      setState(() {
        _liveMapItems = items.map(ActiveTripMapItem.fromJson).toList();
      });
    } catch (_) {
      // Keep showing whatever we already have — the next event will retry.
    }
  }

  /// Detects common API failures and returns a user-friendly message.
  String _explainError(Object error) {
    final msg = error.toString();

    // Backend returned HTML instead of JSON — server is down or wrong URL
    if (msg.contains('<!DOCTYPE') ||
        msg.contains('<html') ||
        msg.contains('not valid JSON')) {
      return 'The API server is not responding with valid data. '
          'Please check that:\n'
          '• The backend server is running\n'
          '• The API base URL in ApiService is correct\n'
          '• You are not hitting the Flutter web server instead of the API';
    }

    // Network / connection refused
    if (msg.contains('Connection refused') ||
        msg.contains('Failed host lookup') ||
        msg.contains('NetworkException') ||
        msg.contains('SocketException')) {
      return 'Cannot reach the API server. Check your network connection '
          'and ensure the backend is running.';
    }

    // Timeout
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'The API request timed out. The server may be slow or unreachable.';
    }

    // 401 / 403
    if (msg.contains('401') || msg.contains('Unauthorized')) {
      return 'Authentication failed. Please log in again.';
    }
    if (msg.contains('403') || msg.contains('Forbidden')) {
      return 'You do not have permission to access this data.';
    }

    // 404
    if (msg.contains('404') || msg.contains('Not Found')) {
      return 'The API endpoint was not found. The backend routes may not be configured correctly.';
    }

    // 500
    if (msg.contains('500') || msg.contains('Internal Server Error')) {
      return 'The server encountered an internal error. Please try again later.';
    }

    // Fallback — show the raw message but cleaned up
    return msg.length > 200 ? '${msg.substring(0, 200)}…' : msg;
  }

  Future<_DashboardData> _load() async {
    // Stats + active trips concurrently; other panels are optional.
    final results = await Future.wait([
      ApiService.get('/dashboard/stats/'),
      ApiService.list('/dashboard/active-trips/'),
    ]);

    final stats = results[0] as Map<String, dynamic>;
    final activeTripsList = results[1] as List<Map<String, dynamic>>;

    // Optional panels — silently ignore failures so a broken sub-endpoint
    // doesn't take down the whole dashboard.
    final pending = await _safeList('/trips/?status=REQUESTED');
    final drivers = await _safeList('/drivers/profiles/');
    final invoices = await _safeList('/billing/invoices/');

    return _DashboardData(
      kpi: DashboardKpi.fromStats(stats),
      mapItems: activeTripsList.map(ActiveTripMapItem.fromJson).toList(),
      activeTrips: activeTripsList.map(Trip.fromJson).toList(),
      pendingBookings: pending.map(Booking.fromJson).toList(),
      drivers: drivers.map(Driver.fromJson).toList(),
      invoices: invoices.map(Invoice.fromJson).toList(),
    );
  }

  Future<List<Map<String, dynamic>>> _safeList(String path) async {
    try {
      return await ApiService.list(path);
    } catch (_) {
      return [];
    }
  }

  void _reload() {
    _fadeController.reset();
    setState(() {
      _future = _load();
      _liveMapItems = null;
    });
  }

  void _onDataLoaded(_DashboardData data) {
    _fadeController.forward();
    _liveMapItems ??= List.of(data.mapItems);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return PageScaffold(
            title: 'Dashboard',
            description:
                'Real-time overview of Tiba Safari medical transport operations.',
            child: const _ShimmerLoading(),
          );
        }
        if (snap.hasError) {
          return PageScaffold(
            title: 'Dashboard',
            description:
                'Real-time overview of Tiba Safari medical transport operations.',
            actions: [
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Retry',
              ),
            ],
            child: _ErrorCard(
              message: _explainError(snap.error!),
              onRetry: _reload,
            ),
          );
        }

        final data = snap.data!;
        _onDataLoaded(data);
        return PageScaffold(
          title: 'Dashboard',
          description:
              'Real-time overview of Tiba Safari medical transport operations.',
          actions: [
            _RefreshButton(onTap: _reload),
          ],
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kpiGrid(data.kpi),
                const SizedBox(height: 20),
                _operationsStrip(data),
                const SizedBox(height: 24),
                _mapAndTrips(data),
                const SizedBox(height: 24),
                _lowerPanels(data),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── KPI Grid ───────────────────────────────────────────────────────

  Widget _kpiGrid(DashboardKpi kpi) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth > 700
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.8,
          children: [
            KPICard(
              label: 'Active Trips',
              value: kpi.activeTrips.toString(),
              icon: Icons.local_hospital_rounded,
              accent: const Color(0xFF0EA5E9),
              trend: kpi.activeTripsTrend,
            ),
            KPICard(
              label: 'Pending Bookings',
              value: kpi.pendingBookings.toString(),
              icon: Icons.pending_actions_rounded,
              accent: const Color(0xFFF59E0B),
              trend: kpi.pendingBookingsTrend,
            ),
            KPICard(
              label: 'Drivers Online',
              value: kpi.driversOnline.toString(),
              icon: Icons.people_rounded,
              accent: AppTheme.primary,
              trend: kpi.driversOnlineTrend,
            ),
            KPICard(
              label: 'Revenue Today',
              value: formatCompactCurrency(kpi.revenueToday),
              icon: Icons.trending_up_rounded,
              accent: const Color(0xFF7C3AED),
              trend: kpi.revenueTrend,
            ),
          ],
        );
      },
    );
  }

  // ─── Operations Strip ───────────────────────────────────────────────

  Widget _operationsStrip(_DashboardData data) {
    final online = data.drivers.where((d) => d.status == 'online').length;
    final onTrip = data.drivers.where((d) => d.status == 'on_trip').length;
    final overdue =
        data.invoices.where((i) => i.status == 'overdue').length;
    final outstanding = data.invoices
        .where((i) => i.status != 'paid')
        .fold(0.0, (sum, invoice) => sum + invoice.amount);

    final tiles = [
      _SummaryTile(
        icon: Icons.assignment_late_rounded,
        label: 'Dispatch Queue',
        value: data.pendingBookings.length.toString(),
        caption: 'pending requests',
        color: const Color(0xFFF59E0B),
        onTap: () => widget.nav.navigate(ViewKey.bookingsPending),
      ),
      _SummaryTile(
        icon: Icons.health_and_safety_rounded,
        label: 'Driver Capacity',
        value: '$online / ${data.drivers.length}',
        caption: '$onTrip currently on trips',
        color: AppTheme.primary,
        onTap: () => widget.nav.navigate(ViewKey.driversList),
      ),
      _SummaryTile(
        icon: Icons.receipt_long_rounded,
        label: 'Outstanding Billing',
        value: formatCompactCurrency(outstanding),
        caption: '$overdue overdue invoice${overdue == 1 ? '' : 's'}',
        color: const Color(0xFF7C3AED),
        onTap: () => widget.nav.navigate(ViewKey.billingInvoices),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 850;
        return wide
            ? Row(
                children: tiles
                    .expand(
                        (tile) => [Expanded(child: tile), const SizedBox(width: 12)])
                    .toList()
                  ..removeLast(),
              )
            : Column(
                children: tiles
                    .expand((tile) => [tile, const SizedBox(height: 10)])
                    .toList()
                  ..removeLast(),
              );
      },
    );
  }

  // ─── Map + Active Trips ─────────────────────────────────────────────

  Widget _mapAndTrips(_DashboardData data) {
    final mapItems = _liveMapItems ?? data.mapItems;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _mapCard(mapItems)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _activeTripsCard(data.activeTrips)),
            ],
          );
        }
        return Column(
          children: [
            _mapCard(mapItems),
            const SizedBox(height: 16),
            _activeTripsCard(data.activeTrips),
          ],
        );
      },
    );
  }

  Widget _mapCard(List<ActiveTripMapItem> items) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.my_location_rounded,
            iconColor: const Color(0xFF0EA5E9),
            title: 'Live Map',
            subtitle:
                '${items.length} active trip${items.length == 1 ? '' : 's'}',
            trailing: _ViewAllButton(
              onTap: () => widget.nav.navigate(ViewKey.tripsActive),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LiveMap(trips: items, height: 360),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeTripsCard(List<Trip> trips) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.local_shipping_rounded,
            iconColor: AppTheme.primary,
            title: 'Active Trips',
            subtitle: '${trips.length} ongoing',
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 384),
            child: trips.isEmpty
                ? const _EmptyPanel(
                    icon: Icons.local_shipping_outlined,
                    title: 'No active trips',
                    subtitle: 'Trips in progress will appear here.',
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    itemCount: trips.length,
                    itemBuilder: (context, index) {
                      final trip = trips[index];
                      final meta = tripStatus(trip.status);
                      return _TripRow(
                        trip: trip,
                        meta: meta,
                        onTap: () =>
                            widget.nav.openDetail('trip', trip.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Lower Panels ───────────────────────────────────────────────────

  Widget _lowerPanels(_DashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 950) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _dispatchQueue(data.pendingBookings)),
              const SizedBox(width: 16),
              Expanded(child: _driverAvailability(data.drivers)),
            ],
          );
        }
        return Column(
          children: [
            _dispatchQueue(data.pendingBookings),
            const SizedBox(height: 16),
            _driverAvailability(data.drivers),
          ],
        );
      },
    );
  }

  Widget _dispatchQueue(List<Booking> bookings) {
    final rows = bookings.take(5).toList();
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.pending_actions_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Dispatch Queue',
            subtitle: 'Pending bookings requiring action',
            trailing: _ViewAllButton(
              label: 'Open',
              onTap: () => widget.nav.navigate(ViewKey.bookingsPending),
            ),
          ),
          if (rows.isEmpty)
            const _EmptyPanel(
              icon: Icons.task_alt_rounded,
              title: 'All clear',
              subtitle: 'No pending bookings right now.',
            )
          else
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  for (int i = 0; i < rows.length; i++) ...[
                    _BookingRow(
                      booking: rows[i],
                      onTap: () =>
                          widget.nav.openDetail('booking', rows[i].id),
                    ),
                    if (i < rows.length - 1) const _SubtleDivider(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _driverAvailability(List<Driver> drivers) {
    final ordered = [...drivers]
      ..sort((a, b) {
        const order = {'online': 0, 'on_trip': 1, 'offline': 2};
        return (order[a.status] ?? 3).compareTo(order[b.status] ?? 3);
      });
    final rows = ordered.take(5).toList();

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.people_rounded,
            iconColor: AppTheme.primary,
            title: 'Driver Availability',
            subtitle: 'Roster status for dispatch',
            trailing: _ViewAllButton(
              label: 'Manage',
              onTap: () => widget.nav.navigate(ViewKey.driversList),
            ),
          ),
          if (rows.isEmpty)
            const _EmptyPanel(
              icon: Icons.people_outline_rounded,
              title: 'No driver data',
              subtitle: 'Driver roster will appear here.',
            )
          else
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(
                children: [
                  for (int i = 0; i < rows.length; i++) ...[
                    _DriverRow(
                      driver: rows[i],
                      onTap: () =>
                          widget.nav.openDetail('driver', rows[i].id),
                    ),
                    if (i < rows.length - 1) const _SubtleDivider(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════════
// SHARED REUSABLE PIECES
// ═══════════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ViewAllButton({this.label = 'View all', required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: AppTheme.primary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtleDivider extends StatelessWidget {
  const _SubtleDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppTheme.border.withValues(alpha: 0.5),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon,
                  size: 22,
                  color: AppTheme.textMuted.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textMuted.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.textMuted.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ROW WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _TripRow extends StatelessWidget {
  final Trip trip;
  final StatusMeta meta;
  final VoidCallback onTap;

  const _TripRow({
    required this.trip,
    required this.meta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              AvatarCircle(
                name: trip.driver?.name ?? '?',
                color: AppTheme.primary,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            trip.reference,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                            tone: meta.tone, label: meta.label, dot: true),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trip.patient?.name ?? "-"}  ·  ${trip.pickup} → ${trip.dropoff}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted.withValues(alpha: 0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppTheme.textMuted.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  final Booking booking;
  final VoidCallback onTap;

  const _BookingRow({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pending_actions_rounded,
                    color: Color(0xFFF59E0B), size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.reference,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${booking.patient?.name ?? "-"}  ·  ${booking.pickup} → ${booking.dropoff}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted.withValues(alpha: 0.8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCurrency(booking.fare),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  final Driver driver;
  final VoidCallback onTap;

  const _DriverRow({required this.driver, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = driverStatus(driver.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              AvatarCircle(
                name: driver.name,
                color: avatarColor(driver.avatarColor),
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      driver.vehicle?.plate ?? 'No assigned vehicle',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted.withValues(alpha: 0.8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              StatusBadge(tone: meta.tone, label: meta.label, dot: true),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SUMMARY TILE
// ═══════════════════════════════════════════════════════════════════════

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color color;
  final VoidCallback onTap;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        caption,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppTheme.textMuted.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ACTION BUTTONS
// ═══════════════════════════════════════════════════════════════════════

class _RefreshButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RefreshButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.refresh_rounded, size: 18),
      tooltip: 'Refresh',
      style: IconButton.styleFrom(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// LOADING & ERROR STATES
// ═══════════════════════════════════════════════════════════════════════

class _ShimmerLoading extends StatelessWidget {
  const _ShimmerLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.8,
          children: List.generate(
              4, (_) => const _ShimmerBox(height: double.infinity)),
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: _ShimmerBox(height: 72)),
            SizedBox(width: 12),
            Expanded(child: _ShimmerBox(height: 72)),
            SizedBox(width: 12),
            Expanded(child: _ShimmerBox(height: 72)),
          ],
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Expanded(flex: 5, child: _ShimmerBox(height: 420)),
            SizedBox(width: 16),
            Expanded(flex: 3, child: _ShimmerBox(height: 420)),
          ],
        ),
      ],
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double height;
  const _ShimmerBox({required this.height});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              Colors.grey.shade100,
              Colors.grey.shade200,
              (math.sin(value * math.pi * 2) + 1) / 2,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    // Detect if this is a connectivity/API issue for special styling
    final isApiError = message.contains('API') ||
        message.contains('server') ||
        message.contains('network') ||
        message.contains('reach');

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isApiError
                      ? Colors.orange.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  isApiError
                      ? Icons.cloud_off_rounded
                      : Icons.error_outline_rounded,
                  color: isApiError
                      ? Colors.orange.shade300
                      : Colors.red.shade300,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isApiError ? 'Cannot connect to server' : 'Something went wrong',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textMuted.withValues(alpha: 0.65),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 15),
                    label: const Text('Try Again'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: hook up clipboard — Clipboard.setData(ClipboardData(text: message));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Copy Error'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontSize: 12.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// DATA CLASS
// ═══════════════════════════════════════════════════════════════════════

class _DashboardData {
  final DashboardKpi kpi;
  final List<ActiveTripMapItem> mapItems;
  final List<Trip> activeTrips;
  final List<Booking> pendingBookings;
  final List<Driver> drivers;
  final List<Invoice> invoices;

  const _DashboardData({
    required this.kpi,
    required this.mapItems,
    required this.activeTrips,
    required this.pendingBookings,
    required this.drivers,
    required this.invoices,
  });
} 