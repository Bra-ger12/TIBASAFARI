import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/data_table.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class BookingsAllScreen extends StatefulWidget {
  final NavState nav;
  const BookingsAllScreen({super.key, required this.nav});
  @override
  State<BookingsAllScreen> createState() => _BookingsAllScreenState();
}

class _BookingsAllScreenState extends State<BookingsAllScreen> {
  late Future<List<Booking>> _future;
  String _status = 'all';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Booking>> _load() async {
    final path = _status == 'all' ? '/trips/' : '/trips/?status=$_status';
    final items = await ApiService.list(path);
    return items.map(Booking.fromJson).toList();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'All Bookings',
      description: 'Complete booking history with search and filtering.',
      actions: [
        _statusDropdown(),
      ],
      child: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          if (snap.hasError) {
            return ErrorState(message: '${snap.error}', onRetry: _reload);
          }
          var rows = snap.data ?? [];
          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            rows = rows
                .where((b) =>
                    b.reference.toLowerCase().contains(q) ||
                    b.patientName.toLowerCase().contains(q) ||
                    b.pickup.toLowerCase().contains(q) ||
                    b.dropoff.toLowerCase().contains(q) ||
                    b.driverName.toLowerCase().contains(q))
                .toList();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchField(
                  hintText: 'Search by reference, patient, route...',
                  onChanged: (v) => setState(() => _search = v)),
              const SizedBox(height: 16),
              DataTable2<Booking>(
                columns: const [
                  DataColumn2(label: 'Reference', key: 'reference', width: 140),
                  DataColumn2(label: 'Patient', key: 'patient', width: 160),
                  DataColumn2(label: 'Route', key: 'route', width: 220, hideOnSmall: true),
                  DataColumn2(label: 'Scheduled', key: 'scheduled', width: 130, hideOnSmall: true),
                  DataColumn2(label: 'Driver', key: 'driver', width: 160, hideOnSmall: true),
                  DataColumn2(label: 'Fare', key: 'fare', width: 90, numeric: true),
                  DataColumn2(label: 'Status', key: 'status', width: 110),
                ],
                rows: rows,
                rowKey: (b) => b.id,
                onRowTap: (b) => widget.nav.openDetail('booking', b.id),
                cellValues: (b) => [
                  Text(b.reference,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                  Text(b.patientName.isEmpty ? '—' : b.patientName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  '${b.pickup} → ${b.dropoff}',
                  formatDate(b.scheduledAt, withTime: true),
                  b.driverName.isEmpty ? 'Unassigned' : b.driverName,
                  formatCurrency(b.fare),
                  () {
                    final meta = bookingStatus(b.status);
                    return StatusBadge(
                        tone: meta.tone, label: meta.label, dot: true);
                  }(),
                ],
                emptyMessage: 'No bookings found.',
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
          DropdownMenuItem(value: 'REQUESTED', child: Text('Requested')),
          DropdownMenuItem(value: 'ASSIGNED', child: Text('Assigned')),
          DropdownMenuItem(value: 'ACCEPTED', child: Text('Accepted')),
          DropdownMenuItem(value: 'EN_ROUTE', child: Text('En Route')),
          DropdownMenuItem(value: 'ARRIVED', child: Text('Arrived')),
          DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
          DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _status = v);
          _reload();
        },
      ),
    );
  }
}
