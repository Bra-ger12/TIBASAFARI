import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/data_table.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';
import '../widgets/live_map.dart';

class TripsActiveScreen extends StatefulWidget {
  final NavState nav;
  const TripsActiveScreen({super.key, required this.nav});
  @override
  State<TripsActiveScreen> createState() => _TripsActiveScreenState();
}

class _TripsActiveScreenState extends State<TripsActiveScreen> {
  late Future<List<Trip>> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  Future<List<Trip>> _load() async {
    final items = await ApiService.list(
        '/trips/?status=ASSIGNED,ACCEPTED,EN_ROUTE,ARRIVED');
    return items.map(Trip.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Active Trips',
      description: 'Live trips currently in progress across the fleet.',
      child: FutureBuilder<List<Trip>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          if (snap.hasError) {
            return ErrorState(
              message: '${snap.error}',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final trips = snap.data ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: AppTheme.border))),
                      child: Row(children: [
                        const Icon(Icons.my_location,
                            size: 16, color: Color(0xFF0EA5E9)),
                        const SizedBox(width: 8),
                        const Text('Live Map Overview',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${trips.length} active',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textMuted)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: LiveMap(
                        trips: trips
                            .map((t) => ActiveTripMapItem(
                                  id: t.id,
                                  reference: t.reference,
                                  lat: t.currentLat ?? t.pickupLat,
                                  lng: t.currentLng ?? t.pickupLng,
                                  driverName: t.driver?.name ?? '—',
                                  patientName: t.patient?.name ?? '—',
                                  pickup: t.pickup,
                                  dropoff: t.dropoff,
                                  status: t.status,
                                  vehiclePlate: t.vehicle?.plate ?? '—',
                                ))
                            .toList(),
                        height: 300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DataTable2<Trip>(
                columns: const [
                  DataColumn2(label: 'Reference', key: 'reference', width: 140),
                  DataColumn2(label: 'Patient', key: 'patient', width: 160),
                  DataColumn2(label: 'Driver', key: 'driver', width: 160, hideOnSmall: true),
                  DataColumn2(label: 'Vehicle', key: 'vehicle', width: 120, hideOnSmall: true),
                  DataColumn2(label: 'Started', key: 'started', width: 130),
                  DataColumn2(label: 'Fare', key: 'fare', width: 90, numeric: true),
                  DataColumn2(label: 'Status', key: 'status', width: 110),
                ],
                rows: trips,
                rowKey: (t) => t.id,
                onRowTap: (t) => widget.nav.openDetail('trip', t.id),
                cellValues: (t) => [
                  Text(t.reference,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0EA5E9))),
                  Text(t.patient?.name ?? '—',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  t.driver?.name ?? '—',
                  t.vehicle?.plate ?? '—',
                  formatDate(t.startedAt, withTime: true),
                  formatCurrency(t.fare),
                  () {
                    final m = tripStatus(t.status);
                    return StatusBadge(tone: m.tone, label: m.label, dot: true);
                  }(),
                ],
                emptyMessage: 'No active trips right now.',
              ),
            ],
          );
        },
      ),
    );
  }
}
