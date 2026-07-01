import 'package:flutter/material.dart';

import '../../core/models/driver_session.dart';
import '../../core/theme/colors.dart';

class EarningsScreen extends StatelessWidget {
  final DriverSession session;

  const EarningsScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final completed = session.completedTrips;

    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        title: const Text(
          'Earnings',
          style: TextStyle(color: cTealDeep, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: cTealDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [cTeal, cTealDark]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Earnings",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TSh ${_formatTzs(session.earningsTodayTzs)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        label: 'Trips today',
                        value: session.tripsToday.toString(),
                        inverted: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Metric(
                        label: 'Completed',
                        value: completed.length.toString(),
                        inverted: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cBorder),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: cAmber),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Fare totals will update when the backend includes trip fare or payout fields.',
                    style: TextStyle(
                      color: cMuted,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Completed Trips',
            style: TextStyle(
              color: cTealDeep,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (completed.isEmpty)
            const _EmptyCompletedTrips()
          else
            ...completed.map(
              (trip) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CompletedTripTile(trip: trip),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTzs(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool inverted;

  const _Metric({
    required this.label,
    required this.value,
    this.inverted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: inverted ? Colors.white.withValues(alpha: 0.15) : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: inverted ? Colors.white70 : cMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: inverted ? Colors.white : cTealDeep,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedTripTile extends StatelessWidget {
  final DriverAssignedTrip trip;

  const _CompletedTripTile({required this.trip});

  @override
  Widget build(BuildContext context) {
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
            decoration: const BoxDecoration(
              color: cTealLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: cTeal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.patientName,
                  style: const TextStyle(
                    color: cTealDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  trip.destination,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: cMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trip.pickupTime,
            style: const TextStyle(
              color: cMutedLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCompletedTrips extends StatelessWidget {
  const _EmptyCompletedTrips();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.payments_outlined, color: cMutedLight, size: 48),
          SizedBox(height: 14),
          Text(
            'No completed paid trips yet',
            style: TextStyle(
              color: cTealDeep,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Completed trip payouts will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cMuted),
          ),
        ],
      ),
    );
  }
}
