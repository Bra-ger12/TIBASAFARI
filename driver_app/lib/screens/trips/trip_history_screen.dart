import 'package:flutter/material.dart';
import '../../core/models/driver_session.dart';
import '../../core/theme/colors.dart';

enum HistoryFilter { all, completed, cancelled }

class TripHistoryScreen extends StatefulWidget {
  final DriverSession session;

  const TripHistoryScreen({super.key, required this.session});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  late DriverSession _session;
  HistoryFilter _currentFilter = HistoryFilter.all;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  List<DriverAssignedTrip> get _filteredTrips {
    // Usually history implies completed or cancelled trips, but we allow "All" to show everything not active.
    switch (_currentFilter) {
      case HistoryFilter.all:
        return _session.assignedTrips
            .where((t) => t.status == TripAssignmentStatus.completed || t.status == TripAssignmentStatus.cancelled)
            .toList();
      case HistoryFilter.completed:
        return _session.assignedTrips
            .where((t) => t.status == TripAssignmentStatus.completed)
            .toList();
      case HistoryFilter.cancelled:
        return _session.assignedTrips
            .where((t) => t.status == TripAssignmentStatus.cancelled)
            .toList();
    }
  }

  void _showTripDetails(DriverAssignedTrip trip) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) => _TripDetailsBottomSheet(trip: trip),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        title: const Text(
          'Trip History',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: cTealDeep,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: cTealDark,
        elevation: 0,
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          const SizedBox(height: 20),
          Expanded(
            child: _filteredTrips.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _filteredTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _filteredTrips[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TripHistoryCard(
                          trip: trip,
                          onTap: () => _showTripDetails(trip),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cTealLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildFilterTab(HistoryFilter.all, 'All'),
          _buildFilterTab(HistoryFilter.completed, 'Completed'),
          _buildFilterTab(HistoryFilter.cancelled, 'Cancelled'),
        ],
      ),
    );
  }

  Widget _buildFilterTab(HistoryFilter filter, String label) {
    final isSelected = _currentFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentFilter = filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: cTeal.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? cTeal : cMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: cTealLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 60, color: cTeal),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Trips Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cTealDeep,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentFilter == HistoryFilter.all
                  ? "You haven't completed any trips yet."
                  : 'No ${_currentFilter.name} trips to show.',
              style: const TextStyle(fontSize: 14, color: cMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/* ── History card ── */

class _TripHistoryCard extends StatelessWidget {
  final DriverAssignedTrip trip;
  final VoidCallback onTap;

  const _TripHistoryCard({required this.trip, required this.onTap});

  Color _statusColor(TripAssignmentStatus s) {
    switch (s) {
      case TripAssignmentStatus.completed:
        return cTeal;
      case TripAssignmentStatus.cancelled:
        return cError;
      default:
        return cMuted;
    }
  }

  String _statusLabel(TripAssignmentStatus s) {
    switch (s) {
      case TripAssignmentStatus.completed:
        return 'Completed';
      case TripAssignmentStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(trip.status);
    
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cBorder),
            boxShadow: [
              BoxShadow(
                color: cTeal.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  trip.status == TripAssignmentStatus.completed
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 26,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.patientName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: cTealDeep,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: cMutedLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            trip.destination,
                            style: const TextStyle(
                              fontSize: 12,
                              color: cMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _statusLabel(trip.status).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    trip.pickupTime,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: cTeal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded, color: cMutedLight),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ── Details bottom sheet ── */

class _TripDetailsBottomSheet extends StatelessWidget {
  final DriverAssignedTrip trip;
  const _TripDetailsBottomSheet({required this.trip});

  Color _statusColor(TripAssignmentStatus s) {
    switch (s) {
      case TripAssignmentStatus.completed:
        return cTeal;
      case TripAssignmentStatus.cancelled:
        return cError;
      default:
        return cMuted;
    }
  }

  String _statusLabel(TripAssignmentStatus s) {
    switch (s) {
      case TripAssignmentStatus.completed:
        return 'Completed';
      case TripAssignmentStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(trip.status);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cDivider,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Trip Details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cTealDeep,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(trip.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _row('Trip ID', trip.id),
          _row('Patient', trip.patientName),
          _row('Appointment', trip.appointmentType),
          const SizedBox(height: 16),
          const Divider(color: cDivider, height: 1),
          const SizedBox(height: 16),
          _row('Pickup', trip.pickupAddress),
          _row('Destination', trip.destination),
          const SizedBox(height: 16),
          const Divider(color: cDivider, height: 1),
          const SizedBox(height: 16),
          _row('Pickup Time', trip.pickupTime),
          if (trip.specialRequirements.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: cDivider, height: 1),
            const SizedBox(height: 16),
            _row('Requirements', trip.specialRequirements.join(', ')),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: cTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: cMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cTealDeep,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
