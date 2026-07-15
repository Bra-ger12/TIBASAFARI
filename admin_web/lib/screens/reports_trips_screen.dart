import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../services/csv.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';  // ✅ ADD THIS

class ReportsTripsScreen extends StatefulWidget {
  final NavState nav;  // ✅ ADD THIS
  const ReportsTripsScreen({super.key, required this.nav});  // ✅ ADD THIS

  @override
  State<ReportsTripsScreen> createState() => _ReportsTripsScreenState();
}

class _ReportsTripsScreenState extends State<ReportsTripsScreen> {
  late Future<Map<String, dynamic>> _future;
  DateTimeRange? _range;
  
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  
  Future<Map<String, dynamic>> _load() async {
    final params = <String>[];
    if (_range != null) {
      params.add('scheduled_at__gte=${_range!.start.toIso8601String()}');
      params.add('scheduled_at__lte=${_range!.end.toIso8601String()}');
    }
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final items = await ApiService.list('/trips/$q');
    final trips = items.map(Trip.fromJson).toList();
    final completed = trips.where((t) => t.status == 'COMPLETED').toList();
    final cancelled = trips.where((t) => t.status == 'CANCELLED').toList();
    final totalRevenue =
        completed.fold<double>(0, (s, t) => s + t.fare);
    final totalDistance =
        completed.fold<double>(0, (s, t) => s + t.distanceKm);
    return {
      'trips': items,
      'total': trips.length,
      'completed': completed.length,
      'cancelled': cancelled.length,
      'total_revenue': totalRevenue,
      'total_distance': totalDistance,
      'avg_fare': completed.isEmpty ? 0.0 : totalRevenue / completed.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Trip Report',
      description: 'Analyze trip volume, distance, and revenue over a date range.',
      actions: [
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2024),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDateRange: _range,
            );
            if (picked != null) {
              setState(() {
                _range = picked;
                _future = _load();
              });
            }
          },
          icon: const Icon(Icons.date_range, size: 16),
          label: Text(_range == null
              ? 'Pick a date range'
              : '${formatDate(_range!.start.toIso8601String())} – ${formatDate(_range!.end.toIso8601String())}'),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final data = await _future;
            final trips = (data['trips'] as List)
                .map((e) => Trip.fromJson(e as Map<String, dynamic>))
                .toList();
            if (trips.isEmpty) return;
            exportCsv(
                'trip-report.csv',
                trips
                    .map((t) => {
                          'Reference': t.reference,
                          'Patient': t.patientName,
                          'PatientEmail': t.patientEmail,
                          'Driver': t.driverName,
                          'Vehicle': t.vehicle?.plate ?? '',
                          'Pickup': t.pickup,
                          'Dropoff': t.dropoff,
                          'DistanceKm': t.distanceKm,
                          'Fare': t.fare,
                          'Status': t.status,
                          'StartedAt':
                              formatDate(t.startedAt, withTime: true),
                        })
                    .toList());
          },
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Export CSV'),
        ),
      ],
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          if (snap.hasError || snap.data == null) {
            return ErrorState(
              message: '${snap.error ?? 'Unknown error'}',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final summary = snap.data!;
          final trips = (snap.data!['trips'] as List)
              .map((e) => Trip.fromJson(e as Map<String, dynamic>))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 900 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.0,
                  children: [
                    _stat('Total Trips', summary['total'].toString(),
                        const Color(0xFF0EA5E9)),
                    _stat('Completed', summary['completed'].toString(),
                        AppTheme.primary),
                    _stat('Total Revenue',
                        formatCurrency((summary['total_revenue'] as num).toDouble()),
                        const Color(0xFF7C3AED)),
                    _stat('Total Distance',
                        '${summary['total_distance']} km', const Color(0xFFF59E0B)),
                  ],
                );
              }),
              const SizedBox(height: 16),
              SectionCard(
                title: 'Trip Log',
                padding: EdgeInsets.zero,
                action: Text('${trips.length} records',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted)),
                child: trips.isEmpty
                    ? const EmptyState(
                        icon: Icons.assessment, title: 'No trips in range.')
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width - 64),
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Reference')),
                              DataColumn(label: Text('Patient')),
                              DataColumn(label: Text('Patient Email')),
                              DataColumn(label: Text('Driver')),
                              DataColumn(label: Text('Route')),
                              DataColumn(label: Text('Distance'), numeric: true),
                              DataColumn(label: Text('Fare'), numeric: true),
                              DataColumn(label: Text('Status')),
                            ],
                            rows: trips
                                .map((t) => DataRow(cells: [
                                      DataCell(Text(t.reference,
                                          style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600))),
                                      DataCell(Text(t.patientName.isEmpty
                                          ? '—'
                                          : t.patientName)),
                                      DataCell(Text(t.patientEmail.isEmpty
                                          ? '—'
                                          : t.patientEmail)),
                                      DataCell(Text(t.driverName.isEmpty
                                          ? '—'
                                          : t.driverName)),
                                      DataCell(Text('${t.pickup} → ${t.dropoff}',
                                          style: const TextStyle(fontSize: 11))),
                                      DataCell(Text('${t.distanceKm} km')),
                                      DataCell(Text(formatCurrency(t.fare))),
                                      DataCell(() {
                                        final m = tripStatus(t.status);
                                        return StatusBadge(
                                            tone: m.tone,
                                            label: m.label,
                                            dot: true);
                                      }()),
                                    ]))
                                .toList(),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String label, String value, Color accent) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}