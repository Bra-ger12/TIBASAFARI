import 'package:flutter/material.dart';

import '../../core/models/driver_session.dart';
import '../../core/theme/colors.dart';

class TripDetailArguments {
  final DriverSession session;
  final String tripId;

  const TripDetailArguments({required this.session, required this.tripId});
}

class TripDetailScreen extends StatelessWidget {
  final DriverSession session;
  final String tripId;

  const TripDetailScreen({
    super.key,
    required this.session,
    required this.tripId,
  });

  @override
  Widget build(BuildContext context) {
    final trip = _findTrip();

    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        title: const Text(
          'Trip Details',
          style: TextStyle(color: cTealDeep, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: cTealDark,
        elevation: 0,
      ),
      body: trip == null
          ? _MissingTrip(tripId: tripId)
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SummaryCard(trip: trip),
                const SizedBox(height: 16),
                _InfoSection(
                  title: 'Route',
                  rows: [
                    _InfoRow('Pickup', trip.pickupAddress),
                    _InfoRow('Destination', trip.destination),
                    _InfoRow('Pickup Time', trip.pickupTime),
                  ],
                ),
                const SizedBox(height: 16),
                _InfoSection(
                  title: 'Patient',
                  rows: [
                    _InfoRow('Name', trip.patientName),
                    _InfoRow('Appointment', trip.appointmentType),
                  ],
                ),
                if (trip.specialRequirements.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _InfoSection(
                    title: 'Requirements',
                    rows: [_InfoRow('', trip.specialRequirements.join(', '))],
                  ),
                ],
              ],
            ),
    );
  }

  DriverAssignedTrip? _findTrip() {
    for (final trip in session.assignedTrips) {
      if (trip.id == tripId) return trip;
    }
    return null;
  }
}

class _SummaryCard extends StatelessWidget {
  final DriverAssignedTrip trip;

  const _SummaryCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(trip.status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  trip.id,
                  style: const TextStyle(
                    color: cTealDeep,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(trip.status),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            trip.patientName,
            style: const TextStyle(
              color: cTealDeep,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trip.appointmentType,
            style: const TextStyle(color: cMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _statusColor(TripAssignmentStatus status) {
    return switch (status) {
      TripAssignmentStatus.assigned => Colors.blue,
      TripAssignmentStatus.accepted => cTeal,
      TripAssignmentStatus.inProgress => cAmber,
      TripAssignmentStatus.arrived => cAmber,
      TripAssignmentStatus.completed => cTeal,
      TripAssignmentStatus.cancelled => cError,
    };
  }

  String _statusLabel(TripAssignmentStatus status) {
    return switch (status) {
      TripAssignmentStatus.assigned => 'Assigned',
      TripAssignmentStatus.accepted => 'Accepted',
      TripAssignmentStatus.inProgress => 'In progress',
      TripAssignmentStatus.arrived => 'Arrived',
      TripAssignmentStatus.completed => 'Completed',
      TripAssignmentStatus.cancelled => 'Cancelled',
    };
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;

  const _InfoSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: cTealDeep,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map((row) => row),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                  color: cMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: cTealDeep,
                fontWeight: FontWeight.w700,
              ),
              textAlign: label.isEmpty ? TextAlign.left : TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingTrip extends StatelessWidget {
  final String tripId;

  const _MissingTrip({required this.tripId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, color: cMutedLight, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Trip not found',
              style: TextStyle(
                color: cTealDeep,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tripId.isEmpty
                  ? 'No trip was selected.'
                  : 'Trip $tripId is not available in the current session.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: cMuted),
            ),
          ],
        ),
      ),
    );
  }
}
