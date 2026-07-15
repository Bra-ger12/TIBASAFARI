import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/data_table.dart';
import '../widgets/status_badge.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';

class VehiclesListScreen extends StatefulWidget {
  final NavState nav;
  const VehiclesListScreen({super.key, required this.nav});
  @override
  State<VehiclesListScreen> createState() => _VehiclesListScreenState();
}

class _VehiclesListScreenState extends State<VehiclesListScreen> {
  late Future<List<Vehicle>> _future;
  String _status = 'all';
  String _type = 'all';
  final String _search = '';
  
  @override
  void initState() {
    super.initState();
    _future = _load();
  }
  
  Future<List<Vehicle>> _load() async {
    final items = await ApiService.list('/operations/vehicles/');
    var vehicles = items.map(Vehicle.fromJson).toList();
    if (_status != 'all') {
      vehicles = vehicles.where((v) => v.status == _status).toList();
    }
    if (_type != 'all') {
      vehicles = vehicles.where((v) => v.type == _type).toList();
    }
    return vehicles;
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Vehicles',
      description: 'Fleet inventory and vehicle management.',
      actions: [
        FilledButton.icon(
          onPressed: () => widget.nav.navigate(ViewKey.vehicleAdd),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Vehicle'),
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
        ),
      ],
      child: FutureBuilder<List<Vehicle>>(
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
          var rows = snap.data ?? [];
          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            rows = rows
                .where((v) =>
                    v.plate.toLowerCase().contains(q) ||
                    v.model.toLowerCase().contains(q) ||
                    (v.driver?.name.toLowerCase().contains(q) ?? false))
                .toList();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                _statusDropdown(),
                const SizedBox(width: 8),
                _typeDropdown(),
              ]),
              const SizedBox(height: 16),
              DataTable2<Vehicle>(
                columns: const [
                  DataColumn2(label: 'Plate', key: 'plate', width: 120),
                  DataColumn2(label: 'Type', key: 'type', width: 140),
                  DataColumn2(label: 'Capacity', key: 'capacity', width: 100, hideOnSmall: true),
                  DataColumn2(label: 'Driver', key: 'driver', width: 180, hideOnSmall: true),
                  DataColumn2(label: 'Status', key: 'status', width: 110),
                  DataColumn2(label: '', key: 'actions', width: 80),
                ],
                rows: rows,
                rowKey: (v) => v.id,
                cellValues: (v) => [
                  Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),  // ✅ FIXED
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.directions_car,
                          size: 16, color: Color(0xFF0EA5E9)),
                    ),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(v.plate,
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text(v.model,
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textMuted)),
                    ]),
                  ]),
                  vehicleTypeLabel(v.type),
                  '${v.capacity} seats',
                  v.driver?.name ?? 'Unassigned',
                  () {
                    final m = vehicleStatus(v.status);
                    return StatusBadge(tone: m.tone, label: m.label, dot: true);
                  }(),
                  Tooltip(
                    message: 'Edit',
                    child: IconButton(
                      onPressed: () {
                        widget.nav.resetSelection();
                        widget.nav.openDetail('vehicle', v.id);
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      color: AppTheme.primary,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
                emptyMessage: 'No vehicles found.',
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
          DropdownMenuItem(value: 'available', child: Text('Available')),
          DropdownMenuItem(value: 'in_service', child: Text('In Service')),
          DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _status = v);
          _future = _load();
        },
      ),
    );
  }

  Widget _typeDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: _type,
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All types')),
          DropdownMenuItem(value: 'ambulance', child: Text('Ambulance')),
          DropdownMenuItem(
              value: 'wheelchair-van', child: Text('Wheelchair Van')),
          DropdownMenuItem(value: 'van', child: Text('Van')),
          DropdownMenuItem(value: 'car', child: Text('Car')),
          DropdownMenuItem(value: 'minibus', child: Text('Minibus')),
        ],
        onChanged: (v) {
          if (v == null) return;
          setState(() => _type = v);
          _future = _load();
        },
      ),
    );
  }
}