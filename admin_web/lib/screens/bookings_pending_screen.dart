import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/format.dart';
import '../widgets/data_table.dart';
import '../widgets/shared.dart';
import '../widgets/nav.dart';
import '../widgets/assign_driver_dialog.dart';

class BookingsPendingScreen extends StatefulWidget {
  final NavState nav;
  const BookingsPendingScreen({super.key, required this.nav});
  @override
  State<BookingsPendingScreen> createState() => _BookingsPendingScreenState();
}

class _BookingsPendingScreenState extends State<BookingsPendingScreen> {
  late Future<List<Booking>> _future;
  List<Driver> _allDrivers = [];
  String? _needsFilter;
  Booking? _assignTarget;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Booking>> _load() async {
    final items = await ApiService.list('/trips/?status=REQUESTED');
    return items.map(Booking.fromJson).toList();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _loadDrivers() async {
    if (_allDrivers.isNotEmpty) return;
    try {
      final items = await ApiService.list('/drivers/profiles/');
      _allDrivers = items.map(Driver.fromJson).toList();
    } catch (_) {}
  }

  Future<void> _cancel(Booking b) async {
    setState(() => _actionLoading = true);
    try {
      // Goes through the real cancel action (TripService.cancel_trip) so
      // driver availability is restored and notifications/WS pushes fire —
      // a raw PATCH would bypass all of that.
      await ApiService.post('/trips/${b.id}/cancel/', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trip ${b.reference} cancelled')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _assign(String driverId) async {
    if (_assignTarget == null) return;
    setState(() => _actionLoading = true);
    try {
      await ApiService.post(
          '/trips/${_assignTarget!.id}/assign-driver/', {'driver_id': driverId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Driver assigned to ${_assignTarget!.reference}.')));
      if (!mounted) return;
      Navigator.of(context).pop();
      _assignTarget = null;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Pending Bookings',
      description: 'Review and action bookings awaiting confirmation.',
      child: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingRows();
          }
          if (snap.hasError) {
            return ErrorState(message: '${snap.error}', onRetry: _reload);
          }
          final all = snap.data ?? [];
          final filtered = _needsFilter == null
              ? all
              : all
                  .where((b) =>
                      b.specialNeeds?.contains(_needsFilter) ?? false)
                  .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _needsDropdown(),
                  if (_needsFilter != null)
                    TextButton(
                      onPressed: () =>
                          setState(() => _needsFilter = null),
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              DataTable2<Booking>(
                columns: const [
                  DataColumn2(label: 'Reference', key: 'reference', width: 140),
                  DataColumn2(label: 'Patient', key: 'patient', width: 160),
                  DataColumn2(label: 'Route', key: 'route', width: 220, hideOnSmall: true),
                  DataColumn2(label: 'Scheduled', key: 'scheduled', width: 130, hideOnSmall: true),
                  DataColumn2(label: 'Special Needs', key: 'needs', width: 150, hideOnSmall: true),
                  DataColumn2(label: 'Fare', key: 'fare', width: 90, numeric: true),
                  DataColumn2(label: 'Actions', key: 'actions', width: 110),
                ],
                rows: filtered,
                rowKey: (b) => b.id,
                cellValues: (b) => [
                  Text(b.reference,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  Text(b.patientName.isEmpty ? '—' : b.patientName,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  '${b.pickup} → ${b.dropoff}',
                  formatDate(b.scheduledAt, withTime: true),
                  b.specialNeeds == null || b.specialNeeds!.isEmpty
                      ? const Text('—',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted))
                      : Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: b.specialNeeds!
                              .map((n) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDE9FE),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(n,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF6D28D9))),
                                  ))
                              .toList(),
                        ),
                  formatCurrency(b.fare),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        message: 'Assign driver',
                        child: IconButton(
                          onPressed: _actionLoading
                              ? null
                              : () async {
                                  await _loadDrivers();
                                  if (!mounted) return;
                                  setState(() => _assignTarget = b);
                                  if (!context.mounted) return;
                                  showDialog(
                                    context: context,
                                    builder: (_) => AssignDriverDialog(
                                      bookingReference: b.reference,
                                      drivers: _allDrivers,
                                      loading: _actionLoading,
                                      onAssign: _assign,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.person_add, size: 16),
                          constraints: const BoxConstraints(
                              minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      Tooltip(
                        message: 'Cancel',
                        child: IconButton(
                          onPressed: _actionLoading ? null : () => _cancel(b),
                          icon: const Icon(Icons.close, size: 16),
                          color: const Color(0xFFE11D48),
                          constraints: const BoxConstraints(
                              minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
                emptyMessage: 'No pending bookings match your filters.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _needsDropdown() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String?>(
        value: _needsFilter,
        underline: const SizedBox(),
        hint: const Text('Special needs',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        items: const [
          DropdownMenuItem(value: null, child: Text('All special needs')),
          DropdownMenuItem(value: 'Wheelchair', child: Text('Wheelchair')),
          DropdownMenuItem(value: 'Oxygen tank', child: Text('Oxygen tank')),
          DropdownMenuItem(value: 'Stretcher', child: Text('Stretcher')),
          DropdownMenuItem(value: 'Child seat', child: Text('Child seat')),
        ],
        onChanged: (v) => setState(() => _needsFilter = v),
      ),
    );
  }
}