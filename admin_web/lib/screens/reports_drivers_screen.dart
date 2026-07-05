import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../services/csv.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';  // ✅ ADD THIS

class ReportsDriversScreen extends StatefulWidget {
  final NavState nav;  // ✅ ADD THIS
  const ReportsDriversScreen({super.key, required this.nav});  // ✅ ADD THIS

  @override
  State<ReportsDriversScreen> createState() => _ReportsDriversScreenState();
}

class _ReportsDriversScreenState extends State<ReportsDriversScreen> {
  late Future<List<dynamic>> _future;
  
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  
  Future<List<dynamic>> _load() async {
    final items = await ApiService.list('/drivers/profiles/');
    return items
        .map((d) => {
              'name': d['user_full_name'] ?? d['user_email'] ?? '',
              'email': d['user_email'] ?? '',
              'status': (d['is_available'] == true) ? 'online' : 'offline',
              'vehicle': d['vehicle_registration'] ?? '',
              'rating': d['rating'] ?? 0,
              'totalTrips': d['trips_count'] ?? 0,
              'completedTrips': d['trips_count'] ?? 0,
              'revenue': 0,
              'distance': 0,
              'acceptanceRate': 0,
              'licenseNumber': d['license_number'] ?? '',
              'id': d['id'] ?? '',
            })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Driver Report',
      description: 'Performance metrics per driver across the fleet.',
      actions: [
        OutlinedButton.icon(
          onPressed: () async {
            final drivers = await _future;
            if (drivers.isEmpty) return;
            exportCsv(
                'driver-report.csv',
                drivers
                    .map((d) => {
                          'Name': d['name'],
                          'Email': d['email'],
                          'Status': d['status'],
                          'Vehicle': d['vehicle'],
                          'Rating': d['rating'],
                          'TotalTrips': d['totalTrips'],
                          'CompletedTrips': d['completedTrips'],
                          'Revenue': d['revenue'],
                          'DistanceKm': d['distance'],
                          'AcceptanceRate': d['acceptanceRate'],
                        })
                    .toList());
          },
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Export CSV'),
        ),
      ],
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          final drivers = snap.data ?? [];
          return SectionCard(
            title: 'Driver Performance',
            padding: EdgeInsets.zero,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 64),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Driver')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Vehicle')),
                    DataColumn(label: Text('Rating'), numeric: true),
                    DataColumn(label: Text('Trips'), numeric: true),
                    DataColumn(label: Text('Revenue'), numeric: true),
                    DataColumn(label: Text('Acceptance')),
                  ],
                  rows: drivers.asMap().entries.map((e) {
                    final i = e.key;
                    final d = e.value;
                    final m = driverStatus(d['status'] as String);
                    return DataRow(cells: [
                      DataCell(Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted))),
                      DataCell(Row(children: [
                        AvatarCircle(
                            name: d['name'] as String,
                            color: avatarColor(d['avatarColor'] as String?),
                            size: 28),
                        const SizedBox(width: 8),
                        Text(d['name'] as String,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      ])),
                      DataCell(Text(d['email'] as String,
                          style: const TextStyle(fontSize: 11))),
                      DataCell(StatusBadge(
                          tone: m.tone, label: m.label, dot: true)),
                      DataCell(Text(d['vehicle'] as String,
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(
                          (d['rating'] as num).toStringAsFixed(1))),
                      DataCell(Text(d['totalTrips'].toString())),
                      DataCell(Text(
                          formatCurrency((d['revenue'] as num).toDouble()),
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Row(children: [
                        SizedBox(
                          width: 40,
                          child: LinearProgressIndicator(
                            value:
                                (d['acceptanceRate'] as num).toDouble() / 100,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: AppTheme.primary,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${d['acceptanceRate']}%',
                            style: const TextStyle(fontSize: 11)),
                      ])),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}