import 'package:flutter/material.dart';
import '../../core/models/driver_session.dart';
import '../../core/theme/colors.dart';
import '../../services/driver_service.dart';

// ── Main Screen ───────────────────────────────────────────────────────────────
class DriverDashboardScreen extends StatefulWidget {
  final DriverSession session;

  const DriverDashboardScreen({super.key, required this.session});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  late DriverSession _session;
  int _currentIndex = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    try {
      setState(() => _isLoading = true);
      final updatedSession = await DriverService.instance.fetchSession(_session.driverId);
      if (mounted) setState(() => _session = updatedSession);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e'), backgroundColor: cError),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOnline() async {
    final next = !_session.isOnline;
    setState(() => _session = _session.copyWith(isOnline: next));
    
    try {
      await DriverService.instance.setOnlineStatus(
        driverUid: _session.driverId,
        isOnline: next,
      );
      await _loadDriverData();
    } catch (e) {
      setState(() => _session = _session.copyWith(isOnline: !next));
    }
  }

  Future<void> _updateTripStatus(
    DriverAssignedTrip trip,
    TripAssignmentStatus newStatus,
    String actionName,
  ) async {
    try {
      setState(() => _isLoading = true);

      final updatedTrip = newStatus == TripAssignmentStatus.accepted
          ? await DriverService.instance.acceptTrip(
              driverUid: _session.driverId,
              tripId: trip.id,
            )
          : trip.copyWith(status: newStatus);

      final trips = _session.assignedTrips.map((t) => t.id == updatedTrip.id ? updatedTrip : t).toList();
      
      setState(() {
        _session = _session.copyWith(assignedTrips: trips);
        if (newStatus == TripAssignmentStatus.completed) {
          _session = _session.copyWith(tripsToday: _session.tripsToday + 1);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip $actionName successfully!'),
            backgroundColor: cTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update trip: $e'), backgroundColor: cError),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTripDetails(DriverAssignedTrip trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TripDetailsSheet(trip: trip),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(
          children: [
            if (_currentIndex == 0 || _currentIndex == 4)
              _DriverHeader(
                session: _session,
                isProfile: _currentIndex == 4,
              ),
            Expanded(
              child: _isLoading && _session.assignedTrips.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: cTeal))
                  : RefreshIndicator(
                      onRefresh: _loadDriverData,
                      color: cTeal,
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          _buildHomeTab(),
                          _buildActiveTripTab(),
                          _buildHistoryTab(),
                          _buildEarningsTab(),
                          _buildProfileTab(),
                        ],
                      ),
                    ),
            ),
            _DriverBottomNav(
              currentIndex: _currentIndex,
              onTab: (index) => setState(() => _currentIndex = index),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tabs ────────────────────────────────────────────────────────────────────
  
  Widget _buildHomeTab() {
    final active = _session.assignedTrips.where((t) =>
      t.status == TripAssignmentStatus.assigned ||
      t.status == TripAssignmentStatus.accepted ||
      t.status == TripAssignmentStatus.inProgress ||
      t.status == TripAssignmentStatus.arrived
    ).toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusCard(isOnline: _session.isOnline, onToggle: _toggleOnline),
          const SizedBox(height: 20),
          _StatsRow(
            tripsToday: _session.tripsToday,
            earningsTodayTzs: _session.earningsTodayTzs,
            rating: _session.rating,
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Assigned Trips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cTealDeep)),
              if (active.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: cTealLight, borderRadius: BorderRadius.circular(20)),
                  child: Text('${active.length} Active', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cTealDark)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (active.isEmpty)
            _EmptyState(
              icon: _session.isOnline ? Icons.directions_car_rounded : Icons.wifi_off_rounded,
              title: _session.isOnline ? 'Waiting for assignments…' : 'You are offline',
              subtitle: _session.isOnline ? 'New trips will appear here automatically.' : 'Go online to start receiving trip requests.',
            )
          else
            Column(
              children: active.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TripCard(
                  trip: t,
                  onAccept: () => _updateTripStatus(t, TripAssignmentStatus.accepted, 'accepted'),
                  onViewDetails: () => _showTripDetails(t),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveTripTab() {
    final activeTrip = _session.activeTrip;

    if (activeTrip == null) {
      return _EmptyState(
        icon: Icons.map_rounded,
        title: 'No Active Trip',
        subtitle: 'Once you start a trip, it will show up here with live navigation details.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TripCard(
            trip: activeTrip,
            onAccept: () {
              if (activeTrip.status == TripAssignmentStatus.assigned) {
                _updateTripStatus(activeTrip, TripAssignmentStatus.accepted, 'accepted');
              } else if (activeTrip.status == TripAssignmentStatus.accepted) {
                _updateTripStatus(activeTrip, TripAssignmentStatus.inProgress, 'arrival');
              } else if (activeTrip.status == TripAssignmentStatus.inProgress) {
                _updateTripStatus(activeTrip, TripAssignmentStatus.completed, 'completed');
              }
            },
            onViewDetails: () => _showTripDetails(activeTrip),
            isActionButton: true,
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.navigation_rounded, size: 40, color: cTeal),
                const SizedBox(height: 12),
                const Text('Start Navigation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cTealDeep)),
                const SizedBox(height: 8),
                Text(activeTrip.pickupAddress, style: const TextStyle(color: cMuted), textAlign: TextAlign.center),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final completedTrips = _session.assignedTrips.where((t) => t.status == TripAssignmentStatus.completed).toList();

    if (completedTrips.isEmpty) {
      return _EmptyState(
        icon: Icons.history_rounded,
        title: 'No Trip History',
        subtitle: 'Your completed trips will be listed here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: completedTrips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final trip = completedTrips[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: cTealLight, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: cTeal, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.patientName, style: const TextStyle(fontWeight: FontWeight.w700, color: cTealDeep, fontSize: 15)),
                    Text(trip.destination, style: const TextStyle(color: cMuted, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Text(trip.pickupTime, style: const TextStyle(fontWeight: FontWeight.w800, color: cTeal, fontSize: 13)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEarningsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Earnings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cTealDeep)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [cTeal, cTealDark]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: cTeal.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Earnings", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'TSh ${_formatTzs(_session.earningsTodayTzs)}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _EarningStat(label: 'Trips', value: '${_session.tripsToday}'),
                    _EarningStat(label: 'Rating', value: _session.rating.toStringAsFixed(1)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cTealLight,
              border: Border.all(color: cTeal, width: 3),
            ),
            child: const Icon(Icons.person_rounded, size: 50, color: cTeal),
          ),
          const SizedBox(height: 16),
          Text(_session.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cTealDeep)),
          const SizedBox(height: 4),
          Text('Driver ID: ${_session.driverId}', style: const TextStyle(color: cMuted, fontSize: 14)),
          const SizedBox(height: 32),
          _ProfileMenuItem(icon: Icons.person_outline, title: 'Edit Profile', onTap: () {}),
          _ProfileMenuItem(icon: Icons.car_rental_outlined, title: 'Vehicle Details', onTap: () {}),
          _ProfileMenuItem(icon: Icons.help_outline_rounded, title: 'Help & Support', onTap: () {}),
          _ProfileMenuItem(icon: Icons.logout_rounded, title: 'Logout', color: cError, onTap: () {}),
        ],
      ),
    );
  }
  
  String _formatTzs(int v) {
    return v.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

// ── UI Components ─────────────────────────────────────────────────────────────

class _TripDetailsSheet extends StatelessWidget {
  final DriverAssignedTrip trip;
  const _TripDetailsSheet({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cDivider, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          const Text('Trip Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cTealDeep)),
          const SizedBox(height: 20),
          _buildDetailRow('Trip ID', trip.id),
          _buildDetailRow('Patient', trip.patientName),
          _buildDetailRow('Appointment', trip.appointmentType),
          const Divider(color: cDivider, height: 32),
          _buildDetailRow('Pickup', trip.pickupAddress),
          _buildDetailRow('Destination', trip.destination),
          const Divider(color: cDivider, height: 32),
          _buildDetailRow('Pickup Time', trip.pickupTime),
          if (trip.specialRequirements.isNotEmpty) ...[
            const Divider(color: cDivider, height: 32),
            _buildDetailRow('Requirements', trip.specialRequirements.join(', ')),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: cTeal, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 14, color: cMuted, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cTealDeep))),
        ],
      ),
    );
  }
}

class _DriverHeader extends StatelessWidget {
  final DriverSession session;
  final bool isProfile;
  const _DriverHeader({required this.session, this.isProfile = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [cTeal, cTealDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isProfile ? 'My Profile' : 'Welcome back,',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  isProfile ? session.driverId : session.displayName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(session.driverId, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onToggle;
  const _StatusCard({required this.isOnline, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0A0F6E56), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Availability', style: TextStyle(fontSize: 13, color: cMuted, fontWeight: FontWeight.w600)),
              Text(
                isOnline ? 'You are Online' : 'You are Offline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isOnline ? Colors.green : cMuted),
              ),
            ],
          ),
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : cMutedLight, borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: (isOnline ? Colors.green : Colors.grey).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(isOnline ? 'Online' : 'Offline', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int tripsToday;
  final int earningsTodayTzs;
  final double rating;
  const _StatsRow({required this.tripsToday, required this.earningsTodayTzs, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(icon: Icons.directions_car_rounded, color: cBlue, value: '$tripsToday', label: "Today's Trips")),
        const SizedBox(width: 12),
        Expanded(child: _StatTile(icon: Icons.payments_rounded, color: cAmber, value: _formatTzs(earningsTodayTzs), label: 'Earnings (TSh)')),
        const SizedBox(width: 12),
        Expanded(child: _StatTile(icon: Icons.star_rounded, color: Colors.orange, value: rating.toStringAsFixed(1), label: 'Rating')),
      ],
    );
  }

  String _formatTzs(int v) => v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0A0F6E56), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cTealDeep)),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: cMutedLight, fontWeight: FontWeight.w600), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _EarningStat extends StatelessWidget {
  final String label;
  final String value;
  const _EarningStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _TripCard extends StatelessWidget {
  final DriverAssignedTrip trip;
  final VoidCallback onAccept;
  final VoidCallback onViewDetails;
  final bool isActionButton;
  
  const _TripCard({
    required this.trip,
    required this.onAccept,
    required this.onViewDetails,
    this.isActionButton = false,
  });

  @override
  Widget build(BuildContext context) {
    String actionText = 'Accept Trip';
    if (isActionButton) {
      switch (trip.status) {
        case TripAssignmentStatus.assigned: actionText = 'Start Trip / Head to Pickup'; break;
        case TripAssignmentStatus.accepted: actionText = "I've Arrived at Pickup"; break;
        case TripAssignmentStatus.inProgress: actionText = 'Complete Trip'; break;
        default: actionText = 'View Details';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x0D0F6E56), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(trip.patientName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: cTealDeep))),
                _StatusBadge(status: trip.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(trip.appointmentType, style: const TextStyle(fontSize: 13, color: cMuted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            _LocationRow(dotColor: cBlue, label: 'Pickup', address: trip.pickupAddress),
            Padding(
              padding: const EdgeInsets.only(left: 4.5),
              child: Container(width: 1.5, height: 12, color: cDivider),
            ),
            _LocationRow(dotColor: cTeal, label: 'Destination', address: trip.destination),
            if (trip.specialRequirements.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SpecialRequirementsBox(requirements: trip.specialRequirements),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 16, color: cMutedLight),
                    const SizedBox(width: 6),
                    Text(trip.pickupTime, style: const TextStyle(fontSize: 13, color: cMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
                Text(trip.id, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: cTeal)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: isActionButton ? actionText : 'Accept',
                    color: cTeal, textColor: Colors.white, onTap: onAccept,
                  ),
                ),
                const SizedBox(width: 12),
                if (!isActionButton)
                  Expanded(
                    child: _ActionButton(
                      label: 'Details', color: Colors.white, textColor: cTealDeep, borderColor: cBorder, onTap: onViewDetails,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final TripAssignmentStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: config.$2, borderRadius: BorderRadius.circular(20)),
      child: Text(config.$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: config.$3)),
    );
  }

  (String, Color, Color) _getStatusConfig() {
    switch (status) {
      case TripAssignmentStatus.assigned: return ('Assigned', const Color(0xFFE8F5FF), cBlue);
      case TripAssignmentStatus.accepted: return ('Accepted', const Color(0xFFE1F5EE), cTeal);
      case TripAssignmentStatus.inProgress: return ('In Progress', const Color(0xFFFFF4DE), cAmber);
      case TripAssignmentStatus.arrived: return ('Arrived', const Color(0xFFE8F5FF), cBlue);
      case TripAssignmentStatus.completed: return ('Completed', const Color(0xFFE1F5EE), cTeal);
      case TripAssignmentStatus.cancelled: return ('Cancelled', const Color(0xFFFEE8E0), cError);
    }
  }
}

class _LocationRow extends StatelessWidget {
  final Color dotColor;
  final String label;
  final String address;
  const _LocationRow({required this.dotColor, required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: cMutedLight, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(address, style: const TextStyle(fontSize: 14, color: cTealDeep, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpecialRequirementsBox extends StatelessWidget {
  final List<String> requirements;
  const _SpecialRequirementsBox({required this.requirements});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cAmber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: cAmber),
              SizedBox(width: 6),
              Text('Special Requirements', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cAmber)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: requirements.map((r) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cAmber.withValues(alpha: 0.4)),
              ),
              child: Text(r, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cTealDeep)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.color, required this.textColor, this.borderColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color, borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48, alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: borderColor != null ? Border.all(color: borderColor!, width: 1.5) : null,
          ),
          child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: cMutedLight),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cTealDeep), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 14, color: cMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _ProfileMenuItem({required this.icon, required this.title, this.color = cTealDeep, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: cBorder)),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 16),
                Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color))),
                const Icon(Icons.chevron_right_rounded, color: cMutedLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────
class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem({required this.label, required this.icon, required this.activeIcon});
}

class _DriverBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTab;
  const _DriverBottomNav({required this.currentIndex, required this.onTab});

  static const _tabs = [
    _NavItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    _NavItem(label: 'Trip', icon: Icons.directions_car_outlined, activeIcon: Icons.directions_car_rounded),
    _NavItem(label: 'History', icon: Icons.history_outlined, activeIcon: Icons.history_rounded),
    _NavItem(label: 'Earnings', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
    _NavItem(label: 'Profile', icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: _tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              final active = index == currentIndex;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTab(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(active ? tab.activeIcon : tab.icon, size: 24, color: active ? cTeal : cMutedLight),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                          color: active ? cTeal : cMutedLight,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
