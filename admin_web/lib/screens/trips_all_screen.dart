import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/data_table.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class TripsAllScreen extends StatefulWidget {
  final NavState nav;
  const TripsAllScreen({super.key, required this.nav});
  @override
  State<TripsAllScreen> createState() => _TripsAllScreenState();
}

class _TripsAllScreenState extends State<TripsAllScreen> {
  late Future<List<Trip>> _future;
  String _status = 'all';
  String _search = '';
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  Future<List<Trip>> _load() async {
    final path = _status == 'all'
        ? '/trips/'
        : '/trips/?status=${_status.toUpperCase()}';
    final items = await ApiService.list(path);
    return items.map(Trip.fromJson).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'All Trips',
      description: 'Complete trip log with filtering and search.',
      actions: [_statusDropdown()],
      child: FutureBuilder<List<Trip>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          var rows = snap.data ?? [];
          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            rows = rows
                .where((t) =>
                    t.reference.toLowerCase().contains(q) ||
                    (t.patient?.name.toLowerCase().contains(q) ?? false) ||
                    (t.driver?.name.toLowerCase().contains(q) ?? false))
                .toList();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchField(
                  hintText: 'Search trips...',
                  onChanged: (v) => setState(() => _search = v)),
              const SizedBox(height: 16),
              DataTable2<Trip>(
                columns: const [
                  DataColumn2(label: 'Reference', key: 'reference', width: 140),
                  DataColumn2(label: 'Patient', key: 'patient', width: 160),
                  DataColumn2(label: 'Route', key: 'route', width: 220, hideOnSmall: true),
                  DataColumn2(label: 'Distance', key: 'distance', width: 100, hideOnSmall: true),
                  DataColumn2(label: 'Started', key: 'started', width: 130),
                  DataColumn2(label: 'Fare', key: 'fare', width: 90, numeric: true),
                  DataColumn2(label: 'Status', key: 'status', width: 110),
                ],
                rows: rows,
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
                  '${t.pickup} → ${t.dropoff}',
                  '${t.distanceKm} km',
                  formatDate(t.startedAt, withTime: true),
                  formatCurrency(t.fare),
                  () {
                    final m = tripStatus(t.status);
                    return StatusBadge(tone: m.tone, label: m.label, dot: true);
                  }(),
                ],
                emptyMessage: 'No trips found.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: _status,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All statuses')),
          DropdownMenuItem(value: 'active', child: Text('Active')),
          DropdownMenuItem(value: 'completed', child: Text('Completed')),
          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _status = v);
          _future = _load();
        },
      ),
    );
  }
}
