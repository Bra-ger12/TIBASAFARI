import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/data_table.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class DriversListScreen extends StatefulWidget {
  final NavState nav;
  const DriversListScreen({super.key, required this.nav});
  @override
  State<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends State<DriversListScreen> {
  late Future<List<Driver>> _future;
  String _status = 'all';
  String _search = '';
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  Future<List<Driver>> _load() async {
    final items = await ApiService.list('/drivers/profiles/');
    var drivers = items.map(Driver.fromJson).toList();
    if (_status != 'all') {
      drivers = drivers.where((d) => d.status == _status).toList();
    }
    return drivers;
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Drivers',
      description: 'Manage driver roster, availability, and vehicle assignments.',
      actions: [_statusDropdown()],
      child: FutureBuilder<List<Driver>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          var rows = snap.data ?? [];
          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            rows = rows
                .where((d) =>
                    d.name.toLowerCase().contains(q) ||
                    d.phone.toLowerCase().contains(q) ||
                    d.licenseNumber.toLowerCase().contains(q) ||
                    (d.vehicle?.plate.toLowerCase().contains(q) ?? false))
                .toList();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchField(
                  hintText: 'Search drivers...',
                  onChanged: (v) => setState(() => _search = v)),
              const SizedBox(height: 16),
              DataTable2<Driver>(
                columns: const [
                  DataColumn2(label: 'Driver', key: 'driver', width: 220),
                  DataColumn2(label: 'Status', key: 'status', width: 110),
                  DataColumn2(label: 'Vehicle', key: 'vehicle', width: 150, hideOnSmall: true),
                  DataColumn2(label: 'Rating', key: 'rating', width: 90, hideOnSmall: true),
                  DataColumn2(label: 'Trips', key: 'trips', width: 80, numeric: true),
                  DataColumn2(label: 'License', key: 'license', width: 150, hideOnSmall: true),
                  DataColumn2(label: 'Actions', key: 'actions', width: 90),
                ],
                rows: rows,
                rowKey: (d) => d.id,
                onRowTap: (d) => widget.nav.openDetail('driver', d.id),
                cellValues: (d) => [
                  Row(children: [
                    AvatarCircle(
                        name: d.name,
                        color: avatarColor(d.avatarColor),
                        size: 32),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.name,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(d.phone,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                    ]),
                  ]),
                  () {
                    final m = driverStatus(d.status);
                    return StatusBadge(tone: m.tone, label: m.label, dot: true);
                  }(),
                  d.vehicle != null
                      ? Row(children: [
                          const Icon(Icons.directions_car,
                              size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(d.vehicle!.plate,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                        ])
                      : const Text('Unassigned',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                  Row(children: [
                    Icon(Icons.star, size: 12, color: Colors.amber[600]),
                    const SizedBox(width: 2),
                    Text(d.rating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                  d.tripsCount.toString(),
                  Text(d.licenseNumber,
                      style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppTheme.textMuted)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    tooltip: 'Remove driver',
                    onPressed: () => _confirmDelete(d),
                  ),
                ],
                emptyMessage: 'No drivers found.',
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Driver d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Driver?'),
        content: Text(
            'This removes ${d.name}\'s driver profile (license, vehicle assignment, availability). '
            'Their user account and trip history are not affected. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.delete('/drivers/profiles/${d.id}/');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${d.name} removed.')));
      setState(() => _future = _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
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
          DropdownMenuItem(value: 'all', child: Text('All drivers')),
          DropdownMenuItem(value: 'online', child: Text('Online')),
          DropdownMenuItem(value: 'on_trip', child: Text('On Trip')),
          DropdownMenuItem(value: 'offline', child: Text('Offline')),
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
